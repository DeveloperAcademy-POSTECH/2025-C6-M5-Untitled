import Foundation
import UIKit
import CoreLocation
import Combine

@MainActor
final class AlightProximityManager: ObservableObject {
    
    // MARK: - Published 상태
    @Published private(set) var currentStationIndex: Int = 0
    @Published var stations: [BusStation] = []
    @Published private(set) var remainingStations: Int = 0
    @Published private(set) var lastDistance: CLLocationDistance?
    @Published private(set) var canAlight: Bool = false
    @Published private(set) var progress: CGFloat = 0
    @Published private(set) var hasArrived: Bool = false
    
    // MARK: - 의존성
    private let locationService: LocationService
    private let journeyManager: JourneyManager
    private let voiceManager: VoiceAnnouncementManager
    private let busLocationService: BusLocationService = .shared
    
    // MARK: - 내부 상태 (GPS)
    private var cancellable: AnyCancellable?
    
    private var hasEnteredRadius: Bool = false
    private var maxProgress: CGFloat = 0
    private var shouldAnnounce: Bool = false
    
    // GPS 판정 파라미터
    private let detectionRadius: CLLocationDistance = 15
    
    private var previousDistance: CLLocationDistance?
    private var closestDistance: CLLocationDistance = .infinity
    
    // MARK: - TAGO 연동 상태
    private var cityCode: Int?
    private var routeId: String?
    private var targetVehicleNo: String?
    
    // GPS 감지 실패 모니터링
    private var lastStationPassedTime: Date?
    private var stuckCheckTask: Task<Void, Never>?
    private let stuckThresholdSeconds: TimeInterval = 180  // 3분
    
    // MARK: - 콜백
    var onStationPassed: ((Int, String) -> Void)?
    
    // MARK: - Init
    init(
        locationService: LocationService,
        journeyManager: JourneyManager,
        voiceManager: VoiceAnnouncementManager
    ) {
        self.locationService = locationService
        self.journeyManager = journeyManager
        self.voiceManager = voiceManager
    }
    
    // MARK: - 구성 (버스 구간 설정)
    
    func configure(busLegIndex: Int) {
        guard let journey = journeyManager.selectedJourney,
              let busNode = journey.busSegments[safe: busLegIndex] else {
            print("[AlightProximityManager] 유효하지 않은 버스 구간")
            resetInternalState()
            return
        }
        
        stations = busNode.stations
        
        guard stations.count >= 2 else {
            print("[AlightProximityManager] 정류장 부족")
            resetInternalState()
            return
        }
        
        // 0: 탑승 정류장, 1: 다음 정류장부터 감시
        currentStationIndex = 1
        remainingStations = max(0, stations.count - currentStationIndex)
        hasArrived = false
        canAlight = (remainingStations <= 1)
        progress = 0
        maxProgress = 0
        
        // TAGO 컨텍스트 초기화
        cityCode = nil
        routeId = nil
        targetVehicleNo = nil
        
        // GPS 감지 타이머 초기화
        lastStationPassedTime = Date()
        
        resetTrackingForNextStation()
        
        print("[AlightProximityManager] 구성 완료 / 정류장: \(stations.count), 다음 index: \(currentStationIndex), 남은: \(remainingStations)")
        
        ProgressLiveActivityManager.shared.updateRemainingBusStops(remaining: remainingStations)
    }
    
    /// BeforeRideView → "탔어요" 시점에서 ArrivalInfoManager 값 넘겨서 호출
    func applyTagoContext(
        cityCode: Int?,
        routeId: String?,
        targetVehicleNo: String? = nil
    ) {
        guard let cityCode, let routeId else {
            print("[AlightProximityManager] TAGO 컨텍스트 없음")
            return
        }
        
        self.cityCode = cityCode
        self.routeId = routeId
        if let v = targetVehicleNo {
            self.targetVehicleNo = v
        }
        
        print("[AlightProximityManager] TAGO 적용 cityCode=\(cityCode), routeId=\(routeId), vehicle=\(self.targetVehicleNo ?? "nil")")
    }
    
    func setTargetVehicleNo(_ vehicleno: String?) {
        targetVehicleNo = vehicleno
        print("[AlightProximityManager] 대상 차량 설정: \(vehicleno ?? "nil")")
    }
    
    // MARK: - 시작 / 중지
    
    func start() {
        guard !stations.isEmpty else {
            print("[AlightProximityManager] 정류장 정보 없음")
            return
        }
        
        Task {
            do {
                try await locationService.startContinuousUpdates()
                print("[AlightProximityManager] 위치 시작")
            } catch {
                print("[AlightProximityManager] 위치 실패: \(error)")
            }
        }
        
        cancellable?.cancel()
        cancellable = locationService.$location
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                self?.checkStationProximity(currentLocation: loc)
            }
        
        // GPS 감지 실패 모니터링 시작
        startStuckMonitoring()
    }
    
    func stop() {
        cancellable?.cancel()
        cancellable = nil
        locationService.stopContinuousUpdates()
        
        stuckCheckTask?.cancel()
        stuckCheckTask = nil
        
        resetInternalState()
    }
    
    func enableVoiceAnnouncement() {
        shouldAnnounce = true
    }
    
    func disableVoiceAnnouncement() {
        shouldAnnounce = false
    }
    
    // MARK: - GPS 감지 실패 모니터링
    
    private func startStuckMonitoring() {
        stuckCheckTask?.cancel()
        
        stuckCheckTask = Task { [weak self] in
            while let self, !Task.isCancelled, !self.hasArrived {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 1분마다 체크
                
                guard let lastPassed = self.lastStationPassedTime else { continue }
                let elapsed = Date().timeIntervalSince(lastPassed)
                
                // 3분 동안 GPS로 정류장을 감지 못했으면 TAGO로 보정
                if elapsed >= self.stuckThresholdSeconds {
                    print("[AlightProximityManager] GPS 감지 없음 (\(Int(elapsed))초 경과) - TAGO 보정 시도")
                    await self.tryTagoCorrection()
                    
                    // 보정 후 타이머 리셋 (다음 체크를 위해)
                    self.lastStationPassedTime = Date()
                }
            }
            print("[AlightProximityManager] GPS 감지 모니터링 종료")
        }
    }
    
    // MARK: - 메인 로직 (GPS: 근접/도착 감지 + 진행률)
    
    private func checkStationProximity(currentLocation: CLLocation) {
        guard !stations.isEmpty else { return }
        guard let startStation = stations.first,
              let destinationStation = stations.last else { return }
        
        let startLocation = CLLocation(latitude: startStation.latitude,
                                       longitude: startStation.longitude)
        let destinationLocation = CLLocation(latitude: destinationStation.latitude,
                                             longitude: destinationStation.longitude)
        
        // 진행률: "내 위치 기반"
        updateProgress(
            startLocation: startLocation,
            destinationLocation: destinationLocation,
            currentLocation: currentLocation
        )
        
        if hasArrived { return }
        
        // 모든 정류장 지난 상태 안전 처리
        if currentStationIndex >= stations.count {
            hasArrived = true
            remainingStations = 0
            progress = 1.0
            print("[AlightProximityManager] 모든 정류장 통과")
            return
        }
        
        let nextIndex = currentStationIndex
        let nextStation = stations[nextIndex]
        let stationLocation = CLLocation(latitude: nextStation.latitude,
                                         longitude: nextStation.longitude)
        
        let distance = currentLocation.distance(from: stationLocation)
        lastDistance = distance
        
        // 가장 가까운 지점 갱신
        if distance < closestDistance {
            closestDistance = distance
        }
        
        let isLastStation = (nextIndex == stations.count - 1)
        
        // 정류장 통과 감지: 15m 반경 진입/이탈
        if distance <= detectionRadius {
            if !hasEnteredRadius {
                hasEnteredRadius = true
                print("[AlightProximityManager] 정류장 [\(nextIndex)] 반경 진입: \(nextStation.stationName)")
                
                if isLastStation {
                    handleLastStation(distance: distance, station: nextStation)
                }
            }
            previousDistance = distance
            
        } else {
            // 반경을 벗어남
            if hasEnteredRadius {
                // 정상 통과
                print("[AlightProximityManager] 정류장 [\(nextIndex)] 정상 통과: \(nextStation.stationName)")
                markStationPassed(index: nextIndex, name: nextStation.stationName, reason: "GPS 15m 통과")
                
                if !isLastStation {
                    resetTrackingForNextStation()
                }
            }
            
            previousDistance = distance
        }
    }
    
    private func handleLastStation(distance: CLLocationDistance, station: BusStation) {
        if distance <= detectionRadius {
            hasArrived = true
            canAlight = true
            currentStationIndex = stations.count
            remainingStations = 0
            progress = 1.0
            maxProgress = 1.0
            
            print("[AlightProximityManager] 목적지 도착: \(station.stationName)")
            
            Task {
                ProgressLiveActivityManager.shared.updateBusProgress(busProgress: 1.0)
                ProgressLiveActivityManager.shared.updateRemainingBusStops(remaining: 0)
            }
            
            if shouldAnnounce {
                playHapticFeedback()
                voiceManager.announceOneStation()
            }
            
            onStationPassed?(stations.count - 1, station.stationName)
            resetTrackingForNextStation()
        }
    }
    
    // MARK: - 정류장 통과 처리 (공통: GPS / TAGO)
    
    private func markStationPassed(index: Int, name: String, reason: String) {
        guard index == currentStationIndex else { return }
        
        print("[AlightProximityManager] 통과: [\(index)] \(name) (\(reason))")
        
        currentStationIndex = index + 1
        remainingStations = max(0, stations.count - currentStationIndex)
        
        // GPS 감지 타이머 업데이트
        lastStationPassedTime = Date()
        
        print("[AlightProximityManager] 남은 정류장: \(remainingStations)")
        
        Task {
            ProgressLiveActivityManager.shared.updateRemainingBusStops(remaining: self.remainingStations)
        }
        
        if remainingStations <= 1 {
            canAlight = true
        }
        
        if remainingStations == 2, shouldAnnounce {
            playHapticFeedback()
            voiceManager.announceTwoStations()
        }
        
        if remainingStations == 1, shouldAnnounce {
            playHapticFeedback()
            voiceManager.announceOneStation()
        }
        
        onStationPassed?(index, name)
    }
    
    private func resetTrackingForNextStation() {
        hasEnteredRadius = false
        closestDistance = .infinity
        previousDistance = nil
    }
    
    private func resetInternalState() {
        currentStationIndex = 0
        remainingStations = 0
        lastDistance = nil
        canAlight = false
        progress = 0
        hasArrived = false
        maxProgress = 0
        shouldAnnounce = false
        
        cityCode = nil
        routeId = nil
        targetVehicleNo = nil
        
        lastStationPassedTime = nil
        
        resetTrackingForNextStation()
    }
    
    // MARK: - TAGO 보정 (GPS 감지 실패 시에만 호출)
    
    private func tryTagoCorrection() async {
        guard let cityCode,
              let routeId,
              !hasArrived else {
            print("[AlightProximityManager] TAGO 보정 불가 (컨텍스트 없음 또는 도착함)")
            return
        }
        
        do {
            let items = try await busLocationService.fetchRouteBusLocations(
                cityCode: cityCode,
                routeId: routeId
            )
            
            guard !items.isEmpty else {
                print("[AlightProximityManager] TAGO 보정: 버스 위치 데이터 없음")
                return
            }
            
            // 1순위: targetVehicleNo가 있으면 그 차량만 추적
            if let vehicleNo = targetVehicleNo, !vehicleNo.isEmpty {
                guard let myBus = items.first(where: { $0.vehicleno == vehicleNo }) else {
                    print("[AlightProximityManager] TAGO 보정: 대상 차량(\(vehicleNo)) 못 찾음")
                    return
                }
                
                guard let tagoIndex = mapToStationIndex(for: myBus) else {
                    print("[AlightProximityManager] TAGO 보정: 정류장 매핑 실패")
                    return
                }
                
                applyTagoCorrection(tagoIndex: tagoIndex, vehicleNo: myBus.vehicleno)
                return
            }
            
            // 2순위: 차량번호 모르면, 가장 앞쪽(nodeord 큰) 버스 사용
            guard let candidate = items.max(by: { $0.nodeord < $1.nodeord }),
                  let tagoIndex = mapToStationIndex(for: candidate) else {
                print("[AlightProximityManager] TAGO 보정: 후보 차량 선택 실패")
                return
            }
            
            applyTagoCorrection(tagoIndex: tagoIndex, vehicleNo: candidate.vehicleno)
            
        } catch {
            print("[AlightProximityManager] TAGO 보정 실패: \(error.localizedDescription)")
        }
    }
    
    private func applyTagoCorrection(tagoIndex: Int, vehicleNo: String) {
        let gpsIndex = currentStationIndex
        
        print("[AlightProximityManager] TAGO 보정 비교 - GPS: \(gpsIndex), TAGO: \(tagoIndex) (차량: \(vehicleNo))")
        
        // GPS가 더 앞서 있으면 GPS 값 유지
        if gpsIndex >= tagoIndex {
            print("[AlightProximityManager] GPS(\(gpsIndex))가 TAGO(\(tagoIndex))보다 앞섬 - GPS 값 유지")
            return
        }
        
        // TAGO가 더 앞서 있으면 TAGO로 보정
        guard tagoIndex < stations.count else {
            print("[AlightProximityManager] TAGO 인덱스(\(tagoIndex))가 범위 초과")
            return
        }
        
        print("[AlightProximityManager] TAGO 보정 적용: \(gpsIndex) → \(tagoIndex)")
        
        // 놓친 정류장들을 모두 통과 처리
        for idx in gpsIndex..<tagoIndex {
            let name = stations[idx].stationName
            markStationPassed(index: idx, name: name, reason: "TAGO 보정")
        }
        
        resetTrackingForNextStation()
    }
    
    // TAGO 응답 → 우리 정류장 인덱스로 매핑
    private func mapToStationIndex(for bus: BusLocationItem) -> Int? {
        // 1순위: nodeid ↔ localStationId 매핑
        if let idx = stations.firstIndex(where: { $0.localStationId == bus.nodeid }) {
            return idx
        }
        
        // 2순위: nodeord 사용 (정류장 순서와 맞다는 가정)
        if bus.nodeord > 0 {
            let candidate = bus.nodeord - 1
            if stations.indices.contains(candidate) {
                return candidate
            }
        }
        
        // 3순위: 좌표로 가장 가까운 정류장
        let busLoc = CLLocation(latitude: bus.gpslati, longitude: bus.gpslong)
        
        let nearest = stations.enumerated().min { lhs, rhs in
            let l = CLLocation(latitude: lhs.element.latitude, longitude: lhs.element.longitude)
            let r = CLLocation(latitude: rhs.element.latitude, longitude: rhs.element.longitude)
            return busLoc.distance(from: l) < busLoc.distance(from: r)
        }
        
        return nearest?.offset
    }
    
    // MARK: - 진행률 (내 위치 기준)
    
    private func updateProgress(
        startLocation: CLLocation,
        destinationLocation: CLLocation,
        currentLocation: CLLocation
    ) {
        let totalSegments = max(stations.count - 1, 1)
        
        let passedStations = max(currentStationIndex - 1, 0)
        let baseProgress = CGFloat(passedStations) / CGFloat(totalSegments)
        
        var currentSegmentProgress: CGFloat = 0
        
        if currentStationIndex > 1,
           currentStationIndex < stations.count {
            let prev = stations[currentStationIndex - 1]
            let next = stations[currentStationIndex]
            
            let prevLoc = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            let nextLoc = CLLocation(latitude: next.latitude, longitude: next.longitude)
            
            let segmentDistance = prevLoc.distance(from: nextLoc)
            let distanceFromPrev = currentLocation.distance(from: prevLoc)
            
            if segmentDistance > 0 {
                let ratio = min(max(distanceFromPrev / segmentDistance, 0), 1)
                currentSegmentProgress = CGFloat(ratio) / CGFloat(totalSegments)
            }
        }
        
        let total = baseProgress + currentSegmentProgress
        let clamped = min(max(total, 0), 1)
        
        maxProgress = max(maxProgress, clamped)
        progress = maxProgress
        
        Task {
            ProgressLiveActivityManager.shared.updateBusProgress(busProgress: Double(self.progress))
        }
    }
    
    // MARK: - 햅틱
    private func playHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * Double(i)) {
                generator.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - 배열 safe 인덱스

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
