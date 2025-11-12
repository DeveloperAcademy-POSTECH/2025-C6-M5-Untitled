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
    
    // MARK: - 내부 상태
    private var cancellable: AnyCancellable?
    private var shouldAnnounce: Bool = false
    
    // GPS 판정 파라미터
    private let primaryRadius: CLLocationDistance = 50    // 1차 감지 반경
    private let confirmRadius: CLLocationDistance = 30     // 확정 반경
    
    // 진입/이탈 상태 추적
    private var stationProximityState: [Int: Bool] = [:]  // [정류장idx: 30m안에 있는지]
    
    // 건너뛰기 감지
    private var missedStationsCheck: Set<Int> = []
    
    // 정류장 간 거리 및 진행률
    private var segmentDistances: [CLLocationDistance] = []
    private var totalDistance: CLLocationDistance = 0
    
    // TAGO 연동
    private var cityCode: Int?
    private var routeId: String?
    private var targetVehicleNo: String?
    
    // GPS 감지 실패 모니터링
    private var lastStationPassedTime: Date?
    private var stuckCheckTask: Task<Void, Never>?
    private let stuckThresholdSeconds: TimeInterval = 120
    
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
    
    // MARK: - 구성
    
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
        
        // 정류장 간 거리 사전 계산
        calculateSegmentDistances()
        
        currentStationIndex = 1  // 첫 정류장(탑승)은 이미 지남
        remainingStations = max(0, stations.count - currentStationIndex)
        hasArrived = false
        canAlight = (remainingStations <= 1)
        progress = 0
        
        cityCode = nil
        routeId = nil
        targetVehicleNo = nil
        
        lastStationPassedTime = Date()
        missedStationsCheck.removeAll()
        stationProximityState.removeAll()
        
        print("[AlightProximityManager] 구성 완료 / 정류장: \(stations.count), 다음 index: \(currentStationIndex), 남은: \(remainingStations)")
        
        ProgressLiveActivityManager.shared.updateRemainingBusStops(remaining: remainingStations)
    }
    
    // 정류장 간 거리 계산
    private func calculateSegmentDistances() {
        segmentDistances.removeAll()
        totalDistance = 0
        
        for i in 0..<(stations.count - 1) {
            let from = CLLocation(latitude: stations[i].latitude, longitude: stations[i].longitude)
            let to = CLLocation(latitude: stations[i+1].latitude, longitude: stations[i+1].longitude)
            let dist = from.distance(from: to)
            segmentDistances.append(dist)
            totalDistance += dist
        }
        
        print("[AlightProximityManager] 총 거리: \(Int(totalDistance))m, 구간: \(segmentDistances.count)개")
    }
    
    func setTagoContext(cityCode: Int, routeId: String, vehicleNo: String?) {
        self.cityCode = cityCode
        self.routeId = routeId
        self.targetVehicleNo = vehicleNo
        print("[AlightProximityManager] TAGO 컨텍스트 설정: city=\(cityCode), route=\(routeId), vehicle=\(vehicleNo ?? "미지정")")
    }
    
    // 별칭 (BeforeRideView 호환용)
    func applyTagoContext(cityCode: Int?, routeId: String?, targetVehicleNo: String?) {
        guard let city = cityCode, let route = routeId else {
            print("[AlightProximityManager] TAGO 컨텍스트 설정 실패: 필수 값 없음")
            return
        }
        setTagoContext(cityCode: city, routeId: route, vehicleNo: targetVehicleNo)
    }
    
    // MARK: - 시작/중지
    
    func start() async throws {
        guard !stations.isEmpty else {
            print("[AlightProximityManager] 정류장 데이터 없음")
            return
        }
        
        // 위치 권한 확인 및 연속 업데이트 시작 (백그라운드 포함)
        try await locationService.startContinuousUpdates(
            distanceFilter: 10,  // 10m마다 업데이트
            accuracy: kCLLocationAccuracyBest,
            allowsBackgroundUpdates: true
        )
        
        // 위치 업데이트 구독
        cancellable = locationService.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                Task { @MainActor in
                    self?.checkStationProximity(currentLocation: location)
                }
            }
        
        // GPS 감지 실패 모니터링 시작
        startStuckMonitoring()
        
        print("[AlightProximityManager] GPS 추적 시작")
    }
    
    func stop() {
        cancellable?.cancel()
        cancellable = nil
        locationService.stopContinuousUpdates()
        
        stuckCheckTask?.cancel()
        stuckCheckTask = nil
        
        resetInternalState()
        print("[AlightProximityManager] GPS 추적 중지")
    }
    
    func enableVoiceAnnouncement() {
        shouldAnnounce = true
    }
    
    func disableVoiceAnnouncement() {
        shouldAnnounce = false
    }
    
    // MARK: - GPS 감지 실패 모니터링 (TAGO 보정)
    
    private func startStuckMonitoring() {
        stuckCheckTask?.cancel()
        
        stuckCheckTask = Task { [weak self] in
            while let self, !Task.isCancelled, !self.hasArrived {
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                
                guard let lastPassed = self.lastStationPassedTime else { continue }
                let elapsed = Date().timeIntervalSince(lastPassed)
                
                // 2분 동안 GPS로 정류장 감지 못했으면 TAGO 보정
                if elapsed >= self.stuckThresholdSeconds {
                    print("[AlightProximityManager] ⚠️ GPS 감지 없음 (\(Int(elapsed))초) - TAGO 보정 시도")
                    await self.tryTagoCorrection()
                    self.lastStationPassedTime = Date()
                }
            }
        }
    }
    
    // MARK: - 메인 로직: GPS 기반 정류장 감지 (진입/이탈)
    
    private func checkStationProximity(currentLocation: CLLocation) {
        guard !stations.isEmpty, !hasArrived else { return }
        
        // 전체 진행률 업데이트
        updateDetailedProgress(currentLocation: currentLocation)
        
        // 이미 도착했는지 체크
        guard currentStationIndex < stations.count else {
            hasArrived = true
            remainingStations = 0
            progress = 1.0
            print("[AlightProximityManager] ✅ 모든 정류장 통과")
            return
        }
        
        // 남은 모든 정류장의 진입/이탈 상태 추적
        for idx in currentStationIndex..<stations.count {
            let station = stations[idx]
            let stationLoc = CLLocation(latitude: station.latitude, longitude: station.longitude)
            let distance = currentLocation.distance(from: stationLoc)
            
            let wasInside = stationProximityState[idx] ?? false  // 이전에 안에 있었나?
            let isInside = distance <= confirmRadius  // 지금 안에 있나? (30m)
            
            if isInside && !wasInside {
                // 🔔 진입!
                print("[AlightProximityManager] 🔔 정류장[\(idx)] 진입: \(station.stationName) (\(Int(distance))m)")
                stationProximityState[idx] = true
            } else if !isInside && wasInside {
                // 이탈! = 통과 완료!
                print("[AlightProximityManager] ✅ 정류장[\(idx)] 이탈 → 통과 확정: \(station.stationName)")
                
                // 건너뛴 정류장이 있으면 일괄 처리
                if idx > currentStationIndex {
                    print("[AlightProximityManager] ⚠️ 정류장 건너뛰기 감지: \(currentStationIndex) → \(idx)")
                    for missedIdx in currentStationIndex..<idx {
                        handleStationPassed(index: missedIdx, station: stations[missedIdx], reason: "건너뛰기")
                        stationProximityState.removeValue(forKey: missedIdx)
                    }
                }
                
                // 현재 정류장 처리
                handleStationPassed(index: idx, station: station, reason: "GPS 확정")
                stationProximityState.removeValue(forKey: idx)
                
                break  // 처리 완료
            } else if isInside {
                // 계속 안에 있음
                stationProximityState[idx] = true
            }
            
            // 마지막 거리 기록 (현재 목표 정류장)
            if idx == currentStationIndex {
                lastDistance = distance
            }
        }
    }
    
    // 정류장 통과 처리
    private func handleStationPassed(index: Int, station: BusStation, reason: String) {
        guard index == currentStationIndex else { return }
        
        let isLast = (index == stations.count - 1)
        
        print("[AlightProximityManager] ✅ 통과: [\(index)] \(station.stationName) (\(reason))")
        
        // 인덱스 업데이트
        currentStationIndex = index + 1
        remainingStations = max(0, stations.count - currentStationIndex)
        lastStationPassedTime = Date()
        missedStationsCheck.remove(index)
        
        // progress 업데이트 (정류장 기준)
        if totalDistance > 0, segmentDistances.count >= stations.count - 1 {
            var passedDistance: CLLocationDistance = 0
            for i in 0..<(currentStationIndex - 1) {
                if i < segmentDistances.count {
                    passedDistance += segmentDistances[i]
                }
            }
            let newProgress = min(1.0, max(0, passedDistance / totalDistance))
            progress = CGFloat(newProgress)
            
            Task {
                ProgressLiveActivityManager.shared.updateBusProgress(busProgress: newProgress)
            }
            print("[AlightProximityManager] Progress 업데이트: \(String(format: "%.1f%%", newProgress * 100))")
        }
        
        // 라이브 액티비티 업데이트
        Task {
            ProgressLiveActivityManager.shared.updateRemainingBusStops(remaining: self.remainingStations)
        }
        
        print("[AlightProximityManager] 남은 정류장: \(remainingStations)")
        
        // 도착 처리
        if isLast {
            hasArrived = true
            canAlight = true
            progress = 1.0
            Task {
                ProgressLiveActivityManager.shared.updateBusProgress(busProgress: 1.0)
            }
            print("[AlightProximityManager] 🎉 목적지 도착!")
        }
        
        // 하차 안내
        if remainingStations <= 1 {
            canAlight = true
        }
        
        if shouldAnnounce {
            if remainingStations == 2 {
                playHapticFeedback()
                voiceManager.announceTwoStations()
            } else if remainingStations == 1 {
                playHapticFeedback()
                voiceManager.announceOneStation()
            }
        }
        
        onStationPassed?(index, station.stationName)
    }
    
    // MARK: - 진행률 계산 (정류장 간 거리 기반)
    
    private func updateDetailedProgress(currentLocation: CLLocation) {
        guard stations.count >= 2, currentStationIndex > 0 else {
            progress = 0
            return
        }
        
        // 이미 통과한 구간 거리 합
        var passedDistance: CLLocationDistance = 0
        for i in 0..<(currentStationIndex - 1) {
            if i < segmentDistances.count {
                passedDistance += segmentDistances[i]
            }
        }
        
        // 현재 구간 진행률
        if currentStationIndex < stations.count {
            let prevStation = stations[currentStationIndex - 1]
            let nextStation = stations[currentStationIndex]
            
            let prevLoc = CLLocation(latitude: prevStation.latitude, longitude: prevStation.longitude)
            let nextLoc = CLLocation(latitude: nextStation.latitude, longitude: nextStation.longitude)
            
            let segmentLength = prevLoc.distance(from: nextLoc)
            let distanceToNext = currentLocation.distance(from: nextLoc)
            let currentSegmentProgress = max(0, segmentLength - distanceToNext)
            
            passedDistance += currentSegmentProgress
        }
        
        // 전체 진행률
        let newProgress = min(1.0, max(0, passedDistance / totalDistance))
        
        if newProgress > progress {
            progress = CGFloat(newProgress)
            Task {
                ProgressLiveActivityManager.shared.updateBusProgress(busProgress: newProgress)
            }
        }
    }
    
    // MARK: - TAGO 보정 (GPS 실패 시만 사용)
    
    private func tryTagoCorrection() async {
        guard let cityCode, let routeId, !hasArrived else {
            print("[AlightProximityManager] TAGO 보정 불가 (컨텍스트 없음)")
            return
        }
        
        do {
            let items = try await busLocationService.fetchRouteBusLocations(
                cityCode: cityCode,
                routeId: routeId
            )
            
            guard !items.isEmpty else {
                print("[AlightProximityManager] TAGO 보정: 버스 데이터 없음")
                return
            }
            
            // 차량번호 지정되어 있으면 해당 버스만
            let targetBus: BusLocationItem?
            if let vehicleNo = targetVehicleNo, !vehicleNo.isEmpty {
                targetBus = items.first(where: { $0.vehicleno == vehicleNo })
            } else {
                // GPS 기반으로 가장 가까운 버스 선택
                targetBus = try await findClosestBus(from: items)
            }
            
            guard let bus = targetBus,
                  let tagoIndex = mapToStationIndex(for: bus) else {
                print("[AlightProximityManager] TAGO 보정: 매핑 실패")
                return
            }
            
            applyTagoCorrection(tagoIndex: tagoIndex, vehicleNo: bus.vehicleno)
            
        } catch {
            print("[AlightProximityManager] TAGO 보정 실패: \(error)")
        }
    }
    
    // GPS 기반 가장 가까운 버스 찾기
    private func findClosestBus(from items: [BusLocationItem]) async throws -> BusLocationItem? {
        guard let myLocation = try? await locationService.getQuickLocation(maxAge: 60) else {
            // GPS 실패하면 nodeord 큰 것
            return items.max(by: { $0.nodeord < $1.nodeord })
        }
        
        return items.min(by: { bus1, bus2 in
            let loc1 = CLLocation(latitude: bus1.gpslong, longitude: bus1.gpslati)
            let loc2 = CLLocation(latitude: bus2.gpslong, longitude: bus2.gpslati)
            return myLocation.distance(from: loc1) < myLocation.distance(from: loc2)
        })
    }
    
    private func applyTagoCorrection(tagoIndex: Int, vehicleNo: String) {
        let gpsIndex = currentStationIndex
        
        print("[AlightProximityManager] TAGO 보정 비교 - GPS: \(gpsIndex), TAGO: \(tagoIndex) (차량: \(vehicleNo))")
        
        // GPS가 앞서면 유지
        guard tagoIndex > gpsIndex, tagoIndex < stations.count else {
            print("[AlightProximityManager] GPS 값 유지 또는 범위 초과")
            return
        }
        
        print("[AlightProximityManager] 🔄 TAGO 보정 적용: \(gpsIndex) → \(tagoIndex)")
        
        // 놓친 정류장 일괄 처리
        for idx in gpsIndex..<tagoIndex {
            handleStationPassed(index: idx, station: stations[idx], reason: "TAGO 보정")
        }
    }
    
    // 버스 위치 → 정류장 인덱스 매핑
    private func mapToStationIndex(for bus: BusLocationItem) -> Int? {
        // 1순위: localStationId 매칭
        if let idx = stations.firstIndex(where: { $0.localStationId == bus.nodeid }) {
            return idx
        }
        
        // 2순위: 정류장 이름 매칭
        let busStationName = bus.nodenm.replacingOccurrences(of: " ", with: "")
        if let idx = stations.firstIndex(where: {
            $0.stationName.replacingOccurrences(of: " ", with: "") == busStationName
        }) {
            return idx
        }
        
        // 3순위: 좌표 기반 가장 가까운 정류장
        let busLoc = CLLocation(latitude: bus.gpslong, longitude: bus.gpslati)
        if let (idx, _) = stations.enumerated().min(by: { lhs, rhs in
            let loc1 = CLLocation(latitude: lhs.element.latitude, longitude: lhs.element.longitude)
            let loc2 = CLLocation(latitude: rhs.element.latitude, longitude: rhs.element.longitude)
            return busLoc.distance(from: loc1) < busLoc.distance(from: loc2)
        }) {
            let nearest = CLLocation(latitude: stations[idx].latitude, longitude: stations[idx].longitude)
            if busLoc.distance(from: nearest) < 200 {
                return idx
            }
        }
        
        return nil
    }
    
    // MARK: - 내부 유틸
    
    private func resetInternalState() {
        currentStationIndex = 0
        remainingStations = 0
        lastDistance = nil
        canAlight = false
        progress = 0
        hasArrived = false
        shouldAnnounce = false
        
        cityCode = nil
        routeId = nil
        targetVehicleNo = nil
        lastStationPassedTime = nil
        
        missedStationsCheck.removeAll()
        segmentDistances.removeAll()
        totalDistance = 0
        stationProximityState.removeAll()
    }
    
    private func playHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - 배열 safe 인덱스
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
