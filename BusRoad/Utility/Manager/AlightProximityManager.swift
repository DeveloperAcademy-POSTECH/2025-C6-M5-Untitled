import Foundation
import UIKit
import CoreLocation
import Combine

/// 하차 정류장(선택된 여정의 N번째 버스구간 'end')에 대한 근접 감시 매니저
@MainActor
final class AlightProximityManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var currentStationIndex: Int = 0 // 현재까지 지나간 정류장
    @Published private(set) var remainingStations: Int = 0 // 남은 정류장 개수
    @Published private(set) var lastDistance: CLLocationDistance? // 다음 정류장까지 거리
    @Published private(set) var canAlight: Bool = false // 내릴 수 있는지(2정류장 남았을때)
    @Published private(set) var progress: CGFloat = 0 // 진행률
    @Published private(set) var hasArrived: Bool = false // 목적지 도착여부
    
    
    // MARK: - 의존성
    private let locationService: LocationService
    private let journeyManager: JourneyManager
    private let voiceManager: VoiceAnnouncementManager
    
    // MARK: - 내부 상태
    private var cancellable: AnyCancellable?
    private var stations: [BusStation] = []  // 모든 정류장 리스트
    private var hasEnteredRadius: Bool = false // 정류장 안에 들어갔는지
    private let detectionRadius: CLLocationDistance = 10  // 10m 반경
    private var initialDistance: CLLocationDistance?        // 목적지까지 초기 거리
    private var recentDistances: [CLLocationDistance] = []  // GPS 튀는 것 방지
    private let smoothCount: Int = 5                        // 최근 N개 평균
    private var maxProgress: CGFloat = 0                    // 뒤로가기 금지
    private var shouldAnnounce: Bool = false
    
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
        self.currentStationIndex = 0
        self.remainingStations = stations.count
        self.canAlight = false
        self.hasEnteredRadius = false
        self.progress = 0
        self.hasArrived = false
        
        // 진행률 계산 초기화
        initialDistance = nil
        recentDistances.removeAll()
        maxProgress = 0
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
        
        // 진행률 계산 초기화
        initialDistance = nil
        recentDistances.removeAll()
        maxProgress = 0
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
        
        // 목적지(마지막 정류장) 위치
        guard let destination = stations.last else { return }
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        
        // 목적지까지 현재 거리
        let distanceToDestination = currentLocation.distance(from: destinationLocation)
        
        // 진행률 계산
        updateProgress(distanceToDestination: distanceToDestination)
        
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
        
        let isLastStation = (nextStationIndex == stations.count - 1)
        
        // 정류장 통과 감지
        if distance <= detectionRadius {
            if !hasEnteredRadius {
                hasEnteredRadius = true
                print("[AlightProximityManager] 정류장 [\(nextStationIndex)] 반경 진입: \(nextStation.stationName)")
                
                // 마지막 정류장이면 진입만 해도 도착으로 바뀜
                if isLastStation {
                    hasArrived = true
                    progress = 1.0
                    maxProgress = 1.0
                    print("[AlightProximityManager] 목적지 도착!")
                }
            }
        } else {
            if hasEnteredRadius {
                stationPassed(index: nextStationIndex, name: nextStation.stationName)
            }
        }
    }
    
    // 진행률 계산
    private func updateProgress(distanceToDestination: CLLocationDistance) {
        // 최초 업데이트에서 초기 거리 저장
        if initialDistance == nil {
            initialDistance = distanceToDestination
            print("[AlightProximityManager] 초기 목적지까지 거리: \(Int(distanceToDestination))m")
        }
        
        // 최근 N개 이동 평균 (GPS 튀는 것 방지)
        recentDistances.append(distanceToDestination)
        if recentDistances.count > smoothCount {
            recentDistances.removeFirst()
        }
        let smoothed = recentDistances.reduce(0, +) / Double(recentDistances.count)
        
        // 진행률: 1 - (현재/초기)
        if let total = initialDistance, total > 0 {
            let ratio = 1.0 - (smoothed / total)
            let clamped = CGFloat(min(max(ratio, 0), 1))
            
            // 항상 최대값 유지
            maxProgress = max(maxProgress, clamped)
            progress = maxProgress
        } else {
            progress = 0
        }
    }
    
    private func stationPassed(index: Int, name: String) {
        print("[AlightProximityManager] 정류장 통과: [\(index)] \(name)")
        
        currentStationIndex = index + 1
        remainingStations = stations.count - currentStationIndex
        hasEnteredRadius = false
        
        print("[AlightProximityManager] 남은 정류장: \(remainingStations)개")
        
        
        if remainingStations == 2 {
            canAlight = true
            print("[AlightProximityManager] 내릴 준비 - 버튼 활성화!")
            
            if shouldAnnounce {
                playHapticFeedback()
                voiceManager.announceTwoStations()
            }
        }
        else if remainingStations == 1 {
            print("[AlightProximityManager] 다음 정류장 하차!")
            
            
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
    
    func testVoiceAnnouncement() {
        voiceManager.announceTwoStations()
    }
}

// 배열에서 안전하게 값을 꺼내는 기능 추가
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
