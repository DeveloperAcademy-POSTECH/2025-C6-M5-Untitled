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
        busLocationService: BusLocationService = .shared
    ) {
        self.busArrivalService = busArrivalService ?? BusArrivalService()
        self.voiceManager = voiceManager
        self.busLocationService = busLocationService
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
            
            if item.arrtime <= 180 {
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
    
    private func lockVehicleIfNeeded(
        for busRouteNode: BusRouteNode,
        currentItem: BusArrivalItem
    ) async {
        // 이미 잠금된 차량이 있으면 스킵
        guard trackedVehicleNo == nil,
              let cityCode = lastCityCode,
              let routeId = trackedBusRouteId,
              currentItem.routeid == routeId,              // 선택된 도착정보와 동일 노선인지 확인
              let boarding = busRouteNode.stations.first   // 첫 정류장을 승차 정류장으로 사용
        else { return }
        
        do {
            let list = try await busLocationService.fetchRouteBusLocations(
                cityCode: cityCode,
                routeId: routeId
            )
            
            guard !list.isEmpty else {
                print("[ArrivalInfoManager] lockVehicle: 버스 위치 목록 없음")
                return
            }
            
            let boardingLoc = CLLocation(latitude: boarding.latitude,
                                         longitude: boarding.longitude)
            
            // 0. 승차 정류장의 인덱스 (stations[0]이지만, 혹시 몰라서 search)
            let boardingIndex: Int = {
                if let localId = boarding.localStationId,
                   let idx = busRouteNode.stations.firstIndex(where: { $0.localStationId == localId }) {
                    return idx
                }
                if let idx = busRouteNode.stations.firstIndex(where: { $0.stationName == boarding.stationName }) {
                    return idx
                }
                return 0
            }()
            
            let targetPrevStops = max(currentItem.arrprevstationcnt, 0)
            
            // 1. 각 버스를 우리 정류장 인덱스로 매핑
            struct Candidate {
                let bus: BusLocationItem
                let stationIndex: Int      // 버스가 있는 위치에 해당하는 정류장 인덱스 (우리 기준)
                let stopsToBoard: Int      // 승차 정류장까지 남은 정류장 수
                let distanceToBoard: Double
                let score: Int             // arrprevstationcnt와의 차이 (작을수록 좋음)
            }
            
            let mapped: [Candidate] = list.compactMap { bus in
                // 1순위: nodeid ↔ localStationId 매칭
                if let idx = busRouteNode.stations.firstIndex(where: { $0.localStationId == bus.nodeid }) {
                    let busLoc = CLLocation(latitude: bus.gpslati, longitude: bus.gpslong)
                    let dist = busLoc.distance(from: boardingLoc)
                    let stops = max(boardingIndex - idx, 0)
                    let score = abs(targetPrevStops - stops)
                    return Candidate(bus: bus,
                                     stationIndex: idx,
                                     stopsToBoard: stops,
                                     distanceToBoard: dist,
                                     score: score)
                }
                
                // 2순위: nodeord 사용 (TAGO의 nodeord가 1-based 정류장 순서라고 가정)
                if bus.nodeord > 0,
                   busRouteNode.stations.indices.contains(bus.nodeord - 1) {
                    let idx = bus.nodeord - 1
                    let busLoc = CLLocation(latitude: bus.gpslati, longitude: bus.gpslong)
                    let dist = busLoc.distance(from: boardingLoc)
                    let stops = max(boardingIndex - idx, 0)
                    let score = abs(targetPrevStops - stops)
                    return Candidate(bus: bus,
                                     stationIndex: idx,
                                     stopsToBoard: stops,
                                     distanceToBoard: dist,
                                     score: score)
                }
                
                // 3순위: 좌표 기반 근사 (애매하면 나중에 걸러짐)
                let busLoc = CLLocation(latitude: bus.gpslati, longitude: bus.gpslong)
                if let (idx, _) = busRouteNode.stations.enumerated().min(by: { lhs, rhs in
                    let l = CLLocation(latitude: lhs.element.latitude, longitude: lhs.element.longitude)
                    let r = CLLocation(latitude: rhs.element.latitude, longitude: rhs.element.longitude)
                    return busLoc.distance(from: l) < busLoc.distance(from: r)
                }) {
                    let dist = busLoc.distance(from: boardingLoc)
                    let stops = max(boardingIndex - idx, 0)
                    let score = abs(targetPrevStops - stops)
                    return Candidate(bus: bus,
                                     stationIndex: idx,
                                     stopsToBoard: stops,
                                     distanceToBoard: dist,
                                     score: score)
                }
                
                return nil
            }
            
            guard !mapped.isEmpty else {
                print("[ArrivalInfoManager] lockVehicle: 정류장 매핑 실패")
                return
            }
            
            // 2. "아직 승차 정류장 전에 있는 버스"만 후보 (지나간 버스 제외)
            let beforeBoardCandidates = mapped.filter { $0.stationIndex <= boardingIndex }
            guard !beforeBoardCandidates.isEmpty else {
                print("[ArrivalInfoManager] lockVehicle: 승차 정류장 이전 버스 없음")
                return
            }
            
            // 3. arrprevstationcnt와 stopsToBoard가 비슷한 애들 위주로 선택
            //    - score(정류장 갯수 차이)가 2 이내인 애만 신뢰
            //    - 그 중 승차 정류장과의 실제 거리도 작은 버스를 선택
            let thresholdStopsDiff = 2
            
            let strongCandidates = beforeBoardCandidates
                .filter { $0.score <= thresholdStopsDiff && $0.distanceToBoard <= 1500 }
            
            let finalList = strongCandidates.isEmpty ? beforeBoardCandidates : strongCandidates
            
            guard let best = finalList.sorted(by: { lhs, rhs in
                // 1순위: score (arrprevstationcnt와의 오차)
                if lhs.score != rhs.score {
                    return lhs.score < rhs.score
                }
                // 2순위: 승차 정류장까지 실제 거리
                if lhs.distanceToBoard != rhs.distanceToBoard {
                    return lhs.distanceToBoard < rhs.distanceToBoard
                }
                // 3순위: 더 뒤(나중)에 있는 버스(= stationIndex 큰 쪽)를 선호
                return lhs.stationIndex > rhs.stationIndex
            }).first else {
                print("[ArrivalInfoManager] lockVehicle: 후보 선택 실패")
                return
            }
            
            // 4. 선택 결과 잠금
            trackedVehicleNo = best.bus.vehicleno
            trackedVehicleNoPublic = best.bus.vehicleno
            
            print(
                "[ArrivalInfoManager] 차량번호 고정: \(best.bus.vehicleno) " +
                "(stopsToBoard=\(best.stopsToBoard), arrprev=\(targetPrevStops), " +
                "score=\(best.score), dist=\(Int(best.distanceToBoard))m)"
            )
            
        } catch {
            print("[ArrivalInfoManager] 차량번호 잠금 실패: \(error.localizedDescription)")
        }
    }
    
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

