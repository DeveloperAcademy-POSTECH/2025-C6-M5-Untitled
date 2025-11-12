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
    
    private let busArrivalService: BusArrivalService
    private let voiceManager: VoiceAnnouncementManager
    private let busLocationService: BusLocationService
    private let locationService: LocationService
    
    private var refreshTask: Task<Void, Never>?
    private var lastNearestRouteId: String?
    private var lastNearestArrTime: Int?
    private var lastNearestItem: BusArrivalItem?
    
    private var suppressPassUntil: Date?
    private var armedForPass: Bool = false
    
    private var trackedBusRouteId: String?
    private var trackedVehicleNo: String?
    
    @Published var nearestBusInfo: (busNo: String, arrivalText: String)?
    @Published var isArrivingSoon: Bool = false
    @Published var hasPassed: Bool = false
    @Published var lastPassedBusNo: String?
    
    @Published private(set) var lastCityCode: Int?
    @Published private(set) var trackedBusRouteIdPublic: String?
    @Published private(set) var trackedVehicleNoPublic: String?
    
    @MainActor
    private init(
        busArrivalService: BusArrivalService? = nil,
        voiceManager: VoiceAnnouncementManager = .shared,
        busLocationService: BusLocationService = .shared,
        locationService: LocationService = .shared
    ) {
        self.busArrivalService = busArrivalService ?? BusArrivalService()
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
            
            if item.arrtime <= 300 { // 5분
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
        
        guard let firstStation = busRouteNode.stations.first else {
            print("[ArrivalInfoManager] 정류장 정보 없음")
            return (nil, false, nil)
        }
        
        do {
            var nodeId = ""
            if let local = firstStation.localStationId {
                nodeId = local
                print("[ArrivalInfoManager] localStationId 사용: \(nodeId)")
            } else {
                nodeId = try await busArrivalService.fetchNodeId(
                    cityCode: cityCode,
                    stationName: firstStation.stationName
                )
                print("[ArrivalInfoManager] nodeId 조회: \(nodeId)")
            }
            
            let arrivals = try await busArrivalService.fetchBusArrivalInfo(
                cityCode: cityCode,
                nodeId: nodeId
            )
            
            let filtered = arrivals.filter { arrival in
                busRouteNode.busNo.contains(cleanBusNumber(arrival.routeno))
            }
            
            print("[ArrivalInfoManager] 필터 후: \(filtered.map { "\(cleanBusNumber($0.routeno)) - \($0.arrtime)s" })")
            
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
            
            guard let trackedBus = filtered.first(where: { $0.routeid == trackedBusRouteId }) else {
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
              currentItem.routeid == routeId
        else { return }
        
        do {
            // 1. 해당 노선의 모든 버스 위치 가져오기 (이미 routeId로 필터링됨)
            let allBuses = try await busLocationService.fetchRouteBusLocations(
                cityCode: cityCode,
                routeId: routeId
            )
            
            guard !allBuses.isEmpty else {
                print("[ArrivalInfoManager] lockVehicle: 버스 위치 없음")
                return
            }
            
            print("[ArrivalInfoManager] 노선 \(routeId)의 버스 \(allBuses.count)대 조회")
            
            // 2. 사용자 GPS 위치 가져오기
            let myLocation: CLLocation?
            if let cached = locationService.location,
               Date().timeIntervalSince(cached.timestamp) < 300 {
                myLocation = cached
                let age = Int(Date().timeIntervalSince(cached.timestamp))
                print("[ArrivalInfoManager] 📍 캐시된 GPS 사용 (나이: \(age)초)")
            } else {
                print("[ArrivalInfoManager] 📍 새 GPS 요청 중...")
                myLocation = try? await locationService.requestOneShotLocation(timeout: 3)
                if myLocation != nil {
                    print("[ArrivalInfoManager] ✅ 새 GPS 획득 성공")
                } else {
                    print("[ArrivalInfoManager] ⚠️ GPS 획득 실패 (타임아웃)")
                }
            }
            
            // 3. 사용자 위치 기반 선택
            if let location = myLocation {
                selectBusByUserLocation(buses: allBuses, myLocation: location)
            } else {
                print("[ArrivalInfoManager] GPS 없음 - 선택 불가")
            }
            
        } catch {
            print("[ArrivalInfoManager] lockVehicle 실패: \(error)")
        }
    }
    
    // 사용자 현재 위치에서 가장 가까운 버스 선택
    private func selectBusByUserLocation(buses: [BusLocationItem], myLocation: CLLocation) {
        print("[ArrivalInfoManager] 🎯 사용자 위치 기반 버스 선택")
        print("[ArrivalInfoManager] 사용자 위치: (\(myLocation.coordinate.latitude), \(myLocation.coordinate.longitude))")
        
        struct BusCandidate {
            let bus: BusLocationItem
            let distance: CLLocationDistance
        }
        
        let candidates = buses.map { bus -> BusCandidate in
            let busLoc = CLLocation(latitude: bus.gpslong, longitude: bus.gpslati)
            let distance = myLocation.distance(from: busLoc)
            
            print("[ArrivalInfoManager]   \(bus.vehicleno): \(bus.nodenm), 거리 \(Int(distance))m")
            
            return BusCandidate(bus: bus, distance: distance)
        }
        
        // 5km 이내에 있는 버스 중 가장 가까운 것
        let valid = candidates.filter { $0.distance < 5000 }
        
        if valid.isEmpty {
            print("[ArrivalInfoManager] 5km 이내 버스 없음")
            return
        }
        
        guard let closest = valid.min(by: { $0.distance < $1.distance }) else {
            return
        }
        
        trackedVehicleNo = closest.bus.vehicleno
        trackedVehicleNoPublic = closest.bus.vehicleno
        
        print("[ArrivalInfoManager] ✅ 선택: \(closest.bus.vehicleno) (거리: \(Int(closest.distance))m)")
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
    
    // MARK: - 도착 정보 요약
    
    func prepareRouteArrivalSummary(for busRouteNode: BusRouteNode) async -> BusArrivalItem? {
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ArrivalInfoManager] 도시코드 없음")
            return nil
        }
        
        guard let station = busRouteNode.stations.first else {
            print("[ArrivalInfoManager] 정류장 정보 없음")
            return nil
        }
        
        do {
            let nodeId: String
            if let local = station.localStationId {
                nodeId = local
            } else {
                nodeId = try await busArrivalService.fetchNodeId(
                    cityCode: cityCode,
                    stationName: station.stationName
                )
            }
            
            let arrivals = try await busArrivalService.fetchBusArrivalInfo(
                cityCode: cityCode,
                nodeId: nodeId
            )
            
            let filtered = arrivals.filter { arrival in
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
