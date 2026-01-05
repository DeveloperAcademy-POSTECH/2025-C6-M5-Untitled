//
//  ArrivalInfoManager.swift
//  BusRoad
//
//  Created by 박난 on 11/4/25.
//

import CoreLocation
import Combine

@MainActor
final class ArrivalInfoManager: ObservableObject {
    static let shared = ArrivalInfoManager()
    private let voiceManager: VoiceAnnouncementManager
    private let busLocationService: BusLocationService
    private let locationService: LocationService
    
    private var refreshTask: Task<Void, Never>?
    private var lastNearestRouteId: String?
    private var lastNearestItem: BusArrivalItem?
    
    private var suppressPassUntil: Date?
    private var armedForPass: Bool = false
    
    private var trackedBusRouteId: String?
    private var trackedVehicleNo: String?
    
    // 목표 정류장 정보 저장
    private var targetStationNodeId: String?
    private var targetStationOrder: Int?
    
    @Published var lastNearestArrTime: Int?
    
    @Published var nearestBusInfo: (busNo: String, arrivalText: String)?
    @Published var isArrivingSoon: Bool = false
    @Published var hasPassed: Bool = false
    @Published var lastPassedBusNo: String?
    
    @Published private(set) var lastCityCode: Int?
    @Published private(set) var trackedBusRouteIdPublic: String?
    @Published private(set) var trackedVehicleNoPublic: String?
    
    @MainActor
    private init(
        voiceManager: VoiceAnnouncementManager = .shared,
        busLocationService: BusLocationService = .shared,
        locationService: LocationService = .shared
    ) {
        self.voiceManager = voiceManager
        self.busLocationService = busLocationService
        self.locationService = locationService
    }
    
    func startAutoRefresh(for busRouteNode: BusRouteNode) {
        stopAutoRefresh()
        
        refreshTask = Task {
            print("[ArrivalInfoManager] 시작")
            print("[ArrivalInfoManager] 대상 버스: \(busRouteNode.busNo)")
            
            while !Task.isCancelled {
                await refresh(for: busRouteNode)
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        print("[ArrivalInfoManager] 중단")
    }
    
    func endManager() {
        stopAutoRefresh()
        
        nearestBusInfo = nil
        isArrivingSoon = false
        hasPassed = false
        lastPassedBusNo = nil
        
        lastNearestRouteId = nil
        lastNearestArrTime = nil
        lastNearestItem = nil
        
        suppressPassUntil = nil
        armedForPass = false
        
        trackedBusRouteId = nil
        trackedVehicleNo = nil
        trackedBusRouteIdPublic = nil
        trackedVehicleNoPublic = nil
        lastCityCode = nil
        
        targetStationNodeId = nil
        targetStationOrder = nil
    }
    
    func acknowledgePassed() {
        print("[ArrivalInfoManager] 놓쳤어요 처리")
        
        hasPassed = false
        lastPassedBusNo = nil
        nearestBusInfo = nil
        isArrivingSoon = false
        
        suppressPassUntil = Date().addingTimeInterval(12)
        armedForPass = false
        
        lastNearestRouteId = nil
        lastNearestArrTime = nil
        lastNearestItem = nil
        
        trackedBusRouteId = nil
        trackedVehicleNo = nil
        trackedBusRouteIdPublic = nil
        trackedVehicleNoPublic = nil
    }
    
    private func isInSuppressionWindow() -> Bool {
        if let until = suppressPassUntil {
            return Date() < until
        }
        return false
    }
    
    func refresh(for busRouteNode: BusRouteNode) async {
        let result = await refreshNearestBusArrival(for: busRouteNode)
        
        if result.didPass {
            if !isInSuppressionWindow(), armedForPass {
                hasPassed = true
                if let passed = result.passedBus {
                    lastPassedBusNo = cleanBusNumber(passed.routeno)
                    print("[ArrivalInfoManager] 지나감 표시: \(lastPassedBusNo ?? "")")
                    ProgressLiveActivityManager.shared.updateBusArrivalTime(
                        timeTillBusArrival: -1,
                        currentStage: "waitingForBus"
                    )
                }
            } else {
                print("[ArrivalInfoManager] 지나감 감지되었으나 보류 상태")
            }
        }
        
        if let item = result.item {
            updateUI(with: item)
            
            let minutes = item.arrtime / 60
            if minutes <= 2 {
                armedForPass = true
            }
            
            if item.arrtime <= 180 { // 3분
                await lockVehicleIfNeeded(for: busRouteNode, currentItem: item)
            }
        }
    }
    
    func forceRefresh(for busRouteNode: BusRouteNode) async {
        await refresh(for: busRouteNode)
    }
    
    func refreshNearestBusArrival(for busRouteNode: BusRouteNode)
    async -> (item: BusArrivalItem?, didPass: Bool, passedBus: BusArrivalItem?) {
        
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ArrivalInfoManager] 도시코드 찾기 실패")
            return (nil, false, nil)
        }
        
        lastCityCode = cityCode
        let busService = BusServiceFactory.create(cityCode: cityCode)
        
        guard let firstStation = busRouteNode.stations.first else {
            print("[ArrivalInfoManager] 정류장 정보 없음")
            return (nil, false, nil)
        }
        
        
        var allArrivals: [BusArrivalItem] = []
        
        
        
        do {
            // 서울시 로직
            if cityCode == 1000, let seoulService = busService as? SeoulBusService {

                let stationName = firstStation.stationName
                guard let stId = firstStation.localStationId else {
                    print("[Manager] stId(localStationId) 없음 - 서울 도착조회 불가")
                    return (nil, false, nil)
                }

                print("[Manager] stId 기반 검색: stId(\(stId)), 정류장(\(stationName)), 버스(\(busRouteNode.busNo))")

                for targetBusNo in busRouteNode.busNo {
                    let cleanedBusNo = cleanBusNumber(targetBusNo)

                    if let info = BusDataManager.shared.findTargetRouteInfo(
                        stId: stId,
                        stationName: stationName,
                        busName: cleanedBusNo
                    ) {
                        print("[Manager] 매칭 성공! API 호출: stId=\(info.stId), routeId=\(info.routeId), ord=\(info.ord)")

                        let items = try await seoulService.fetchBusArrivalByRoute(
                            stId: info.stId,
                            busRouteId: info.routeId,
                            ord: info.ord
                        )
                        allArrivals.append(contentsOf: items)

                    } else {
                        print("[Manager] CSV 매칭 실패: stId(\(stId)) bus(\(cleanedBusNo))")
                    }
                }
            }
            
            else {
                var nodeId = ""
                if let local = firstStation.localStationId {
                    nodeId = local
                } else {
                    nodeId = try await busService.fetchNodeId(
                        cityCode: cityCode,
                        stationName: firstStation.stationName,
                        arsId: nil
                    )
                }
                
                allArrivals = try await busService.fetchBusArrivalInfo(
                    cityCode: cityCode,
                    nodeId: nodeId
                )
            }
            
            // 필터링 및 결과 처리
            let filtered = allArrivals.filter { arrival in
                busRouteNode.busNo.contains(cleanBusNumber(arrival.routeno))
            }
            
            print("[ArrivalInfoManager] 조회 결과: \(filtered.map { "\(cleanBusNumber($0.routeno)) - \($0.arrtime)s" })")
            
            if filtered.isEmpty {
                if let lastItem = lastNearestItem {
                    let lastNo = cleanBusNumber(lastItem.routeno)
                    if busRouteNode.busNo.contains(lastNo) {
                        print("[ArrivalInfoManager] 리스트에서 사라짐 → 지나감")
                        let passed = lastItem
                        clearTracking()
                        return (nil, true, passed)
                    }
                }
                return (nil, false, nil)
            }
            
            if trackedBusRouteId == nil {
                guard let nearest = filtered.min(by: { $0.arrtime < $1.arrtime }) else {
                    return (nil, false, nil)
                }
                trackedBusRouteId = nearest.routeid
                trackedBusRouteIdPublic = nearest.routeid
                print("[ArrivalInfoManager] 추적 노선 고정: \(nearest.routeid)")
            }
            
            let sameRouteBuses = filtered.filter { $0.routeid == trackedBusRouteId }
            guard let trackedBus = sameRouteBuses.min(by: { $0.arrtime < $1.arrtime }) else {
                if let lastItem = lastNearestItem {
                    print("[ArrivalInfoManager] 추적 버스 사라짐 → 지나감")
                    let passed = lastItem
                    clearTracking()
                    return (nil, true, passed)
                }
                return (nil, false, nil)
            }
            
            print("[ArrivalInfoManager] 추적 중: \(cleanBusNumber(trackedBus.routeno)) - \(trackedBus.arrtime)s")
            
            var didPass = false
            var passedBus: BusArrivalItem?
            
            if let lastId = lastNearestRouteId,
               let lastTime = lastNearestArrTime,
               let lastItem = lastNearestItem {
                
                if lastId != trackedBus.routeid ||
                    (lastTime < trackedBus.arrtime && trackedBus.arrtime > 180) {
                    
                    didPass = true
                    passedBus = lastItem
                    
                    let reason = lastId != trackedBus.routeid ? "버스 교체" : "시간 역행"
                    print("[ArrivalInfoManager] \(reason)로 지나감: \(cleanBusNumber(lastItem.routeno))")
                }
            }
            
            lastNearestRouteId = trackedBus.routeid
            lastNearestArrTime = trackedBus.arrtime
            if lastPassedBusNo == nil{
                ProgressLiveActivityManager.shared.updateBusArrivalTime(
                    timeTillBusArrival: lastNearestArrTime ?? 0,
                    currentStage: "waitingForBus"
                )
            }
            lastNearestItem = trackedBus
            
            return (trackedBus, didPass, passedBus)
            
        } catch {
            print("[ArrivalInfoManager] 에러: \(error.localizedDescription)")
            return (nil, false, nil)
        }
    }
    
    private func clearTracking() {
        lastNearestRouteId = nil
        lastNearestArrTime = nil
        lastNearestItem = nil
        trackedBusRouteId = nil
        trackedBusRouteIdPublic = nil
        trackedVehicleNo = nil
        trackedVehicleNoPublic = nil
        targetStationNodeId = nil
        targetStationOrder = nil
    }
    
    // MARK: - 차량 번호 잠금
    
    private func lockVehicleIfNeeded(
        for busRouteNode: BusRouteNode,
        currentItem: BusArrivalItem
    ) async {
        // 이미 잠금된 차량이 있으면 스킵
        guard trackedVehicleNo == nil,
              let cityCode = lastCityCode,
              let routeId = trackedBusRouteId,
              currentItem.routeid == routeId,
              let targetStation = busRouteNode.stations.first
        else { return }
        
        print("[ArrivalInfoManager] 🎯 탑승 정류장: \(targetStation.stationName)")
        
        do {
            // 1. 노선의 전체 정류장 순서 가져오기
            let allStations = try await busLocationService.fetchRouteStations(
                cityCode: cityCode,
                routeId: routeId
            )
            
            print("[ArrivalInfoManager] 📋 노선 전체 정류장: \(allStations.count)개")
            
            // 2. 탑승 정류장의 정확한 순번 찾기
            func normalize(_ name: String) -> String {
                return name
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .replacingOccurrences(of: "/", with: "")
                    .lowercased()
            }
            
            var targetOrder: Int?
            
            // 2-1. nodeid로 매칭
            if let targetNodeId = targetStation.localStationId,
               let match = allStations.first(where: { $0.nodeid == targetNodeId }) {
                targetOrder = match.nodeord
                print("[ArrivalInfoManager] ✅ 탑승 정류장 순번: \(match.nodeord) (nodeid 매칭)")
            }
            // 2-2. 정류장명으로 매칭
            else {
                let targetNormalized = normalize(targetStation.stationName)
                
                if let match = allStations.first(where: {
                    normalize($0.nodenm) == targetNormalized
                }) {
                    targetOrder = match.nodeord
                    print("[ArrivalInfoManager] ✅ 탑승 정류장 순번: \(match.nodeord) (이름 매칭)")
                } else if let match = allStations.first(where: {
                    let stationNormalized = normalize($0.nodenm)
                    return stationNormalized.contains(targetNormalized) || targetNormalized.contains(stationNormalized)
                }) {
                    targetOrder = match.nodeord
                    print("[ArrivalInfoManager] ⚠️ 탑승 정류장 순번: \(match.nodeord) (부분 매칭: '\(match.nodenm)')")
                }
            }
            
            guard let targetOrder else {
                print("[ArrivalInfoManager] ❌ 전체 노선에서 탑승 정류장을 찾을 수 없음")
                return
            }
            
            // 3. 해당 노선의 모든 버스 위치 가져오기
            let allBuses = try await busLocationService.fetchRouteBusLocations(
                cityCode: cityCode,
                routeId: routeId
            )
            
            guard !allBuses.isEmpty else {
                print("[ArrivalInfoManager] 버스 위치 없음")
                return
            }
            
            print("[ArrivalInfoManager] 🚌 노선 \(routeId)의 버스 \(allBuses.count)대 조회")
            
            // 4. 탑승 정류장 이전에 있는 버스만 필터링
            let validBuses = allBuses.compactMap { bus -> (bus: BusLocationItem, order: Int)? in
                if bus.nodeord < targetOrder {
                    print("[ArrivalInfoManager] \(bus.vehicleno): \(bus.nodenm) (순번 \(bus.nodeord)/\(targetOrder)) ✅")
                    return (bus, bus.nodeord)
                } else {
                    print("[ArrivalInfoManager] \(bus.vehicleno): \(bus.nodenm) (순번 \(bus.nodeord)/\(targetOrder)) ❌ 이미 지나침")
                    return nil
                }
            }
            
            if validBuses.isEmpty {
                print("[ArrivalInfoManager] ⚠️ 모든 버스가 이미 탑승 정류장을 지나침")
                return
            }
            
            // 5. 탑승 정류장에 가장 가까운 버스 선택 (순번이 가장 큰)
            guard let closest = validBuses.max(by: { $0.order < $1.order }) else {
                return
            }
            
            trackedVehicleNo = closest.bus.vehicleno
            trackedVehicleNoPublic = closest.bus.vehicleno
            
            print("[ArrivalInfoManager] ✅ 선택: \(closest.bus.vehicleno) (순번 \(closest.order)/\(targetOrder), \(targetOrder - closest.order)정류장 남음)")
            
        } catch let error as NSError {
            if error.code == 403 {
                print("[ArrivalInfoManager] ⚠️ 버스 위치/노선 API 권한 없음")
            } else {
                print("[ArrivalInfoManager] lockVehicle 실패: \(error.localizedDescription)")
            }
        } catch {
            print("[ArrivalInfoManager] lockVehicle 실패: \(error)")
        }
    }
    
    // MARK: - UI 업데이트
    
    private func updateUI(with item: BusArrivalItem) {
        let minutes = item.arrtime / 60
        let text = minutes < 1 ? "곧 도착" : "\(minutes)분 후"
        let wasArrivingSoon = isArrivingSoon
        
        isArrivingSoon = minutes < 2
        nearestBusInfo = (busNo: cleanBusNumber(item.routeno), arrivalText: text)
        
        if !wasArrivingSoon && isArrivingSoon {
            voiceManager.announceBusArrival()
        }
    }
    
    private func cleanBusNumber(_ busNo: String) -> String {
        var result = busNo
        let pattern = #"\([^()]*\)"#
        while let _ = result.range(of: pattern, options: .regularExpression) {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        if let last = result.last, last.isNumber {
            result += "번"
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func normalizeStationName(_ name: String) -> String {
        name
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
    
    // MARK: - 도착 정보 요약
    
    func prepareRouteArrivalSummary(for busRouteNode: BusRouteNode) async -> BusArrivalItem? {
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            return nil
        }
        
        let busService = BusServiceFactory.create(cityCode: cityCode)
        guard let station = busRouteNode.stations.first else { return nil }
        
        var allArrivals: [BusArrivalItem] = []
        
        do {
            if cityCode == 1000, let seoulService = busService as? SeoulBusService {
                
                let stationName = station.stationName
                let stId = station.localStationId
                
                for targetBusNo in busRouteNode.busNo {
                    if let info = BusDataManager.shared.findTargetRouteInfo(
                        stId: stId,
                        stationName: stationName,
                        busName: targetBusNo
                    ) {
                        let items = try await seoulService.fetchBusArrivalByRoute(
                            stId: info.stId,
                            busRouteId: info.routeId,
                            ord: info.ord
                        )
                        allArrivals.append(contentsOf: items)
                    }
                }
            }
            else {
                var nodeId = ""
                if let local = station.localStationId {
                    nodeId = local
                } else {
                    nodeId = try await busService.fetchNodeId(
                        cityCode: cityCode,
                        stationName: station.stationName,
                        arsId: nil
                    )
                }
                
                allArrivals = try await busService.fetchBusArrivalInfo(
                    cityCode: cityCode,
                    nodeId: nodeId
                )
            }
            
            let filtered = allArrivals.filter { arrival in
                busRouteNode.busNo.contains(cleanBusNumber(arrival.routeno))
            }
            
            if let nearest = filtered.min(by: { $0.arrtime < $1.arrtime }) {
                return nearest
            }
            
            return nil
            
        } catch {
            print("[ArrivalInfoManager] prepare 에러: \(error.localizedDescription)")
            return nil
        }
    }
}
