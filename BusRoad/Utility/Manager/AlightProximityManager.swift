import Foundation
import UIKit
import CoreLocation
import Combine

/// 하차 정류장(선택된 여정의 N번째 버스구간 'end')에 대한 근접 감시 매니저
@MainActor
final class AlightProximityManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var currentStationIndex: Int = 0 // 현재까지 지나간 정류장
    @Published var stations: [BusStation] = []  // 모든 정류장 리스트
    @Published private(set) var remainingStations: Int = 0 // 남은 정류장 개수
    @Published private(set) var lastDistance: CLLocationDistance? // 다음 정류장까지 거리
    @Published private(set) var canAlight: Bool = false // 내릴 수 있는지(1정류장 남았을때)
    @Published private(set) var progress: CGFloat = 0 // 진행률
    @Published private(set) var hasArrived: Bool = false // 목적지 도착여부
    
    
    // MARK: - 의존성
    private let locationService: LocationService
    private let journeyManager: JourneyManager
    private let voiceManager: VoiceAnnouncementManager
    
    // MARK: - 내부 상태
    private var cancellable: AnyCancellable?
    private var hasEnteredRadius: Bool = false // 정류장 안에 들어갔는지
    private let detectionRadius: CLLocationDistance = 35  // 35m 반경
    private var maxProgress: CGFloat = 0                  // 뒤로가기 금지
    private var shouldAnnounce: Bool = false
    
    // 정류장 스킵 감지용
    private var previousDistance: CLLocationDistance? = nil
    private var closestDistance: CLLocationDistance = .infinity
    private var increasingDistanceCount: Int = 0
    private let skipThreshold: CLLocationDistance = 50  // 50m
    
    // MARK: - 콜백
    var onStationPassed: ((Int, String) -> Void)?
    
    // MARK: - Init
    init(locationService: LocationService,
         journeyManager: JourneyManager,
         voiceManager: VoiceAnnouncementManager) {
        self.locationService = locationService
        self.journeyManager = journeyManager
        self.voiceManager = voiceManager
    }
    
    // MARK: - 설정/시작/중지
    
    func configure(busLegIndex: Int) {
        guard let journey = journeyManager.selectedJourney,
              let busNode = journey.busSegments[safe: busLegIndex] else {
            print("[AlightProximityManager] 유효하지 않은 버스 구간입니다.")
            return
        }
        
        // 모든 정류장 저장
        self.stations = busNode.stations
        self.canAlight = false
        self.hasEnteredRadius = false
        self.progress = 0
        self.hasArrived = false
        self.currentStationIndex = 1
        self.remainingStations = max(0, stations.count - 1)  // 탑승지 제외한 남은 정류장
        self.canAlight = (remainingStations <= 1)

        // 진행률 계산 초기화
        maxProgress = 0
        
        // 정류장 추적 초기화
        closestDistance = .infinity
        previousDistance = nil
        increasingDistanceCount = 0
        
        print("[AlightProximityManager] 초기화: 전체 \(stations.count)개, 남은 정류장 \(remainingStations)개")
        
        ProgressLiveActivityManager.shared.updateRemainingBusStops(remaining: remainingStations)
    }
    
    func start() {
        guard !stations.isEmpty else {
            print("[AlightProximityManager] 정류장 정보가 없습니다.")
            return
        }
        
        Task {
            do {
                try await locationService.startContinuousUpdates()
                print("[AlightProximityManager] 위치 서비스 시작됨")
            } catch {
                print("[AlightProximityManager] 위치 서비스 시작 실패: \(error)")
            }
        }
        
        cancellable?.cancel()
        cancellable = locationService.$location
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                self?.checkStationProximity(currentLocation: loc)
            }
    }
    
    func stop() {
        cancellable?.cancel()
        cancellable = nil
        locationService.stopContinuousUpdates()
        
        lastDistance = nil
        hasEnteredRadius = false
        currentStationIndex = 0
        remainingStations = 0
        canAlight = false
        progress = 0
        hasArrived = false
        maxProgress = 0
        
        // 정류장 추적 초기화
        closestDistance = .infinity
        previousDistance = nil
        increasingDistanceCount = 0
    }
    
    func enableVoiceAnnouncement() {
        shouldAnnounce = true
        print("[AlightProximityManager] 음성 안내 활성화")
    }
    
    func disableVoiceAnnouncement() {
        shouldAnnounce = false
        print("[AlightProximityManager] 음성 안내 비활성화")
    }
    
    // MARK: - 정류장 근접 확인
    private func checkStationProximity(currentLocation: CLLocation) {
        let nextStationIndex = currentStationIndex
        
        // 출발지(첫 번째 정류장) 위치
        guard let startStation = stations.first else { return }
        let startLocation = CLLocation(
            latitude: startStation.latitude,
            longitude: startStation.longitude
        )
        
        // 목적지(마지막 정류장) 위치
        guard let destination = stations.last else { return }
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        
        // 진행률 계산
        updateProgress(
            startLocation: startLocation,
            destinationLocation: destinationLocation,
            currentLocation: currentLocation
        )
        
        // 모든 정류장 지났으면 종료
        guard nextStationIndex < stations.count else {
            print("[AlightProximityManager] 모든 정류장을 지났습니다.")
            progress = 1.0
            remainingStations = 0
            hasArrived = true
            return
        }
        
        // 다음 정류장 근접 확인
        let nextStation = stations[nextStationIndex]
        let stationLocation = CLLocation(
            latitude: nextStation.latitude,
            longitude: nextStation.longitude
        )
        
        let distance = currentLocation.distance(from: stationLocation)
        self.lastDistance = distance
        
        // 가장 가까웠던 거리 업데이트
        if distance < closestDistance {
            closestDistance = distance
        }
        
        let isLastStation = (nextStationIndex == stations.count - 1)
        
        //정류장 통과 감지 (3단계 체크)
        // 1단계: 반경 안에 들어왔는지
        if distance <= detectionRadius {
            if !hasEnteredRadius {
                hasEnteredRadius = true
                increasingDistanceCount = 0
                print("[AlightProximityManager] 정류장 [\(nextStationIndex)] 반경 진입: \(nextStation.stationName)")
                
                if isLastStation {
                    hasArrived = true
                    progress = 1.0
                    maxProgress = 1.0
                    print("[AlightProximityManager] 목적지 도착!")
                }
            }
            previousDistance = distance
            
        } else {
            // 2단계: 정상적으로 들어갔다 나왔는지
            if hasEnteredRadius {
                print("[AlightProximityManager] 정상 통과")
                stationPassed(index: nextStationIndex, name: nextStation.stationName)
                resetStationTracking()
                
            } else {
                // 3단계: 놓친 정류장 감지

                // 거리 변화 추적 (초기화 조건 완화)
                if let prevDist = previousDistance {
                    if distance > prevDist {
                        increasingDistanceCount += 1
                    }
                    // else 제거 - 한번 가까워져도 카운트 유지
                }

                // 스킵 조건 
                var shouldSkip = false
                var skipReason = ""

                // 조건 1: 가까이 갔다가 충분히 멀어짐 (가장 중요)
                let wasClose = closestDistance < detectionRadius * 1.5  // 52.5m
                let nowFar = distance > detectionRadius * 2  // 70m

                if wasClose && nowFar {
                    shouldSkip = true
                    skipReason = "접근 후 멀어짐 (최소:\(Int(closestDistance))m → 현재:\(Int(distance))m)"
                }

                // 조건 2: 연속으로 멀어지고 있음 (보조)
                if increasingDistanceCount >= 2 && distance > skipThreshold {
                    shouldSkip = true
                    skipReason = "2회 연속 멀어짐, 현재 \(Int(distance))m"
                }

                // 조건 3: 절대 거리 기준 (안전장치)
                if closestDistance < 80 && distance > 100 {
                    shouldSkip = true
                    skipReason = "80m 이내 접근 후 100m 이상 멀어짐"
                }

                if shouldSkip {
                    print("[AlightProximityManager] 정류장 [\(nextStationIndex)] 스킵: \(nextStation.stationName)")
                    print("[AlightProximityManager] 이유: \(skipReason)")
                    stationPassed(index: nextStationIndex, name: nextStation.stationName)
                    resetStationTracking()
                }
                
                previousDistance = distance
            }
        }
    }
    
    // 정류장 추적 상태 초기화
    private func resetStationTracking() {
        hasEnteredRadius = false
        closestDistance = .infinity
        previousDistance = nil
        increasingDistanceCount = 0
    }
    
    // 진행률 계산 (구간별 방식)
    private func updateProgress(
        startLocation: CLLocation,
        destinationLocation: CLLocation,
        currentLocation: CLLocation
    ) {
        // 전체 구간 수 (정류장 수 - 1)
        let totalSegments = max(stations.count - 1, 1)
        
        // 이미 통과한 정류장 수 (currentStationIndex는 다음 감지할 정류장이므로 -1)
        let passedStations = max(currentStationIndex - 1, 0)
        
        // 기본 진행률 (통과한 구간들)
        let baseProgress = CGFloat(passedStations) / CGFloat(totalSegments)
        
        // 현재 구간의 진행률 계산
        var currentSegmentProgress: CGFloat = 0
        
        if currentStationIndex > 0 && currentStationIndex < stations.count {
            // 이전 정류장 (방금 통과한 정류장)
            let prevStation = stations[currentStationIndex - 1]
            let prevLocation = CLLocation(
                latitude: prevStation.latitude,
                longitude: prevStation.longitude
            )
            
            // 다음 정류장 (지금 가고 있는 정류장)
            let nextStation = stations[currentStationIndex]
            let nextLocation = CLLocation(
                latitude: nextStation.latitude,
                longitude: nextStation.longitude
            )
            
            // 이 구간의 총 거리
            let segmentDistance = prevLocation.distance(from: nextLocation)
            
            // 이전 정류장에서 현재 위치까지의 거리
            let distanceFromPrev = currentLocation.distance(from: prevLocation)
            
            // 현재 구간에서의 진행률 (0.0 ~ 1.0)
            if segmentDistance > 0 {
                let segmentRatio = min(distanceFromPrev / segmentDistance, 1.0)
                // 전체 진행률에서 현재 구간이 차지하는 비율
                currentSegmentProgress = CGFloat(segmentRatio) / CGFloat(totalSegments)
            }
        }
        
        // 최종 진행률 = 통과한 구간 + 현재 구간 진행도
        let totalProgress = baseProgress + currentSegmentProgress
        let clamped = min(max(totalProgress, 0), 1)
        
        // 항상 최대값 유지 (뒤로 가지 않게)
        maxProgress = max(maxProgress, clamped)
        progress = maxProgress
        
        print("[AlightProximityManager] 진행률: \(Int(progress * 100))% (통과: \(passedStations)/\(totalSegments), 현재구간: \(Int(currentSegmentProgress * CGFloat(totalSegments) * 100))%)")
        
        Task {
            ProgressLiveActivityManager.shared.updateBusProgress(busProgress: Double(self.progress))
        }
    }
    
    private func stationPassed(index: Int, name: String) {
        print("[AlightProximityManager] 정류장 통과: [\(index)] \(name)")
        
        currentStationIndex = index + 1
        remainingStations = stations.count - currentStationIndex
        
        print("[AlightProximityManager] 남은 정류장: \(remainingStations)개")
        
        Task {
            ProgressLiveActivityManager.shared.updateRemainingBusStops(remaining: self.remainingStations)
        }
        
        if remainingStations <= 1 {
            canAlight = true
        }
        
        // 2개 남았을 때 음성 알림
        if remainingStations == 2 {
            print("[AlightProximityManager] 2정류장 전 알림!")
            
            if shouldAnnounce {
                playHapticFeedback()
                voiceManager.announceTwoStations()
            }
        }
        
        // 1개 남았을 때 음성 알림
        if remainingStations == 1 {
            print("[AlightProximityManager] 다음 정류장 알림!")
            
            if shouldAnnounce {
                playHapticFeedback()
                voiceManager.announceOneStation()
            }
        }
        onStationPassed?(index, name)
    }
    
    private func playHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        
        // 3번 연속 진동
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + (0.3 * Double(i))) {
                generator.notificationOccurred(.success)
            }
        }
    }
}

// 배열에서 안전하게 값을 꺼내는 기능 추가
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
