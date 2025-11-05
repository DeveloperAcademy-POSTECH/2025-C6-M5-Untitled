//
//  ArrivalInfoManager.swift
//  BusRoad
//
//  Created by 박난 on 11/4/25.
//
import CoreLocation
import Combine

class ArrivalInfoManager: ObservableObject {
    static let shared = ArrivalInfoManager()
    
    private let busArrivalService: BusArrivalService
    
    private var refreshTask: Task<Void, Never>? = nil
    private var lastNearestRouteId: String? = nil
    private var lastNearestArrTime: Int? = nil
    private var lastNearestItem: BusArrivalItem?
    
    // MARK: - Published 상태 (뷰모델이 감시)
    @Published var nearestBusInfo: (busNo: String, arrivalText: String)?
    @Published var isArrivingSoon: Bool = false
    @Published var hasPassed: Bool = false
    @Published var lastPassedBusNo: String?
    
    private init(busArrivalService: BusArrivalService? = nil) {
        self.busArrivalService = busArrivalService ?? BusArrivalService()
    }
    
    // MARK: - 루프 시작
    func startAutoRefresh(for busRouteNode: BusRouteNode) {
        stopAutoRefresh()
        
        refreshTask = Task {
            print("[DEBUG] ArrivalInfoManager: Auto Refresh Started")
            while !Task.isCancelled {
                await refresh(for: busRouteNode)
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            }
        }
    }
    
    // MARK: - 루프 중단
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        print("[DEBUG] ArrivalInfoManager: Auto Refresh Stopped")
    }
    
    // MARK: - 실제 갱신 로직
    func refresh(for busRouteNode: BusRouteNode) async {
        let result = await refreshNearestBusArrival(for: busRouteNode)
        
        // 🚍 매니저 내부에서 Published 업데이트
        if result.didPass {
            hasPassed = true
            if let passed = result.passedBus {
                lastPassedBusNo = cleanBusNumber(passed.routeno)
                print("[ArrivalInfoManager] 🚍 지나감 감지됨 (\(lastPassedBusNo ?? "-"))")
            }
        }
        
        if let item = result.item {
            updateUI(with: item)
        }
    }
    
    // MARK: - 버스 도착 정보 요청
    func refreshNearestBusArrival(for busRouteNode: BusRouteNode)
    async -> (item: BusArrivalItem?, didPass: Bool, passedBus: BusArrivalItem?) {
        
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ERROR] 도시코드 찾기 실패")
            return (nil, false, nil)
        }
        
        guard let firstStation = busRouteNode.stations.first else {
            print("[ERROR] 정류장 정보 없음")
            return (nil, false, nil)
        }
        
        do {
            let nodeId = try await busArrivalService.fetchNodeId(
                cityCode: cityCode,
                stationName: firstStation.stationName,
                arsId: firstStation.nodeId
            )
            
            let arrivals = try await busArrivalService.fetchBusArrivalInfo(
                cityCode: cityCode,
                nodeId: nodeId
            )
            
            guard let nearest = arrivals.min(by: { $0.arrtime < $1.arrtime }) else {
                print("[DEBUG] 도착 예정 버스 없음")
                return (nil, false, nil)
            }
            
            var didPass = false
            var passedBus: BusArrivalItem?
            
            if let lastId = lastNearestRouteId, let lastTime = lastNearestArrTime {
                if lastId != nearest.routeid || (lastTime < 30 && nearest.arrtime > 90) {
                    didPass = true
                    passedBus = lastNearestItem
                }
            }
            
            // 상태 갱신
            lastNearestRouteId = nearest.routeid
            lastNearestArrTime = nearest.arrtime
            lastNearestItem = nearest
            
            return (nearest, didPass, passedBus)
            
        } catch {
            print("[ERROR] \(error.localizedDescription)")
            return (nil, false, nil)
        }
    }
    
    // MARK: - UI용 상태 업데이트
    private func updateUI(with item: BusArrivalItem) {
        let minutes = item.arrtime / 60
        let text = minutes < 1 ? "곧 도착" : "\(minutes)분 후"
        isArrivingSoon = minutes < 2
        nearestBusInfo = (busNo: cleanBusNumber(item.routeno), arrivalText: text)
    }
    
    // MARK: - 버스번호 정리
    private func cleanBusNumber(_ busNo: String) -> String {
        var result = busNo
        let pattern = #"\([^()]*\)"#
        while let _ = result.range(of: pattern, options: .regularExpression) {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        if let lastChar = result.last, lastChar.isNumber {
            result += "번"
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // (경로추천뷰 한번호출) 버스루트노드 -> 정류소ID, 버스리스트(No, Id), 그중 가장 도착시간 짧은 버스No와 남은시간(초)(BusArrivalItem)
    func prepareRouteArrivalSummary(for busRouteNode: BusRouteNode) async -> BusArrivalItem? {
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ERROR] 도시코드를 찾을 수 없습니다.")
            return nil
        }
        
        print("[DEBUG] 도시코드: \(cityCode)")
        
        guard let station = busRouteNode.stations.first else {
            print("[ERROR] 정류소 정보가 없습니다.")
            return nil
        }
        
        do {
            var nodeId = ""
            if let localStationId = station.localStationId {
                nodeId = localStationId
            } else {
                nodeId = try await busArrivalService.fetchNodeId(
                    cityCode: cityCode,
                    stationName: station.stationName,
                    arsId: station.nodeId
                )
            }
            print("[DEBUG] nodeId 조회 성공: \(nodeId)")
            
            let arrivals = try await busArrivalService.fetchBusArrivalInfo(
                cityCode: cityCode,
                nodeId: nodeId
            )
            
            if let nearest = arrivals.min(by: { $0.arrtime < $1.arrtime }) {
                print("[DEBUG] 가장 빨리 오는 버스: \(nearest.routeno), \(nearest.arrtime)초 후 도착")
                return nearest
            } else {
                print("[DEBUG] 도착 예정 버스 없음")
                return nil
            }
            
        } catch {
            print("[ERROR] \(error.localizedDescription)")
            return nil
        }
    }
}
