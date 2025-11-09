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
    
    private var refreshTask: Task<Void, Never>? = nil
    private var lastNearestRouteId: String? = nil
    private var lastNearestArrTime: Int? = nil
    private var lastNearestItem: BusArrivalItem?
    
    private var suppressPassUntil: Date? = nil
    private var armedForPass: Bool = false

    // Published
    @Published var nearestBusInfo: (busNo: String, arrivalText: String)?
    @Published var isArrivingSoon: Bool = false
    @Published var hasPassed: Bool = false
    @Published var lastPassedBusNo: String?
    
    
    // Init
    private init(busArrivalService: BusArrivalService? = nil) {
        self.busArrivalService = busArrivalService ?? BusArrivalService()
    }
    
    
    // Refresh Loop
    func startAutoRefresh(for busRouteNode: BusRouteNode) {
        stopAutoRefresh()
        
        refreshTask = Task {
            print("[DEBUG] ArrivalInfoManager: Auto Refresh Started")
            print("[DEBUG] 추적할 버스 번호들: \(busRouteNode.busNo)")
            
            while !Task.isCancelled {
                await refresh(for: busRouteNode)
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        print("[DEBUG] ArrivalInfoManager: Auto Refresh Stopped")
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
    }
    
    
    // "놓쳤어요" 누른 뒤의 처리
    func acknowledgePassed() {
        print("[DEBUG] acknowledgePassed() 호출됨")
        
        hasPassed = false
        lastPassedBusNo = nil
        
        suppressPassUntil = Date().addingTimeInterval(12)
        armedForPass = false
        
        lastNearestRouteId = nil
        lastNearestArrTime = nil
        lastNearestItem = nil
    }
    
    private func isInSuppressionWindow() -> Bool {
        if let until = suppressPassUntil {
            return Date() < until
        }
        return false
    }
    
    
    // Refresh 내부 로직
    func refresh(for busRouteNode: BusRouteNode) async {
        let result = await refreshNearestBusArrival(for: busRouteNode)
        
        if result.didPass {
            print("[DEBUG] 지나감 감지됨")
            
            if !isInSuppressionWindow(), armedForPass {
                hasPassed = true
                if let passed = result.passedBus {
                    lastPassedBusNo = cleanBusNumber(passed.routeno)
                    print("[DEBUG] 지나감뷰로 표시: \(lastPassedBusNo ?? "")")
                }
            } else {
                print("[DEBUG] 지나감 감지되었으나 suppressed 또는 armedForPass=false")
            }
        }
        
        if let item = result.item {
            updateUI(with: item)
            
            let minutes = item.arrtime / 60
            if minutes <= 2 {
                armedForPass = true
                print("[DEBUG] armedForPass = true (2분 이하 접근)")
            }
        }
    }
    
    
    // 버스 도착 정보 조회 + 지나감 판단
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
            var nodeId = ""
            if let local = firstStation.localStationId {
                nodeId = local
                print("[DEBUG] localStationId 사용: \(nodeId)")
            } else {
                nodeId = try await busArrivalService.fetchNodeId(
                    cityCode: cityCode,
                    stationName: firstStation.stationName
                )
                print("[DEBUG] stationName으로 nodeId 조회: \(nodeId)")
            }
            
            let arrivals = try await busArrivalService.fetchBusArrivalInfo(
                cityCode: cityCode,
                nodeId: nodeId
            )
            
            let filtered = arrivals.filter { arrival in
                busRouteNode.busNo.contains(cleanBusNumber(arrival.routeno))
            }
            
            if filtered.isEmpty {
                if let lastItem = lastNearestItem {
                    let lastNo = cleanBusNumber(lastItem.routeno)
                    if busRouteNode.busNo.contains(lastNo) {
                        print("[DEBUG] 버스가 리스트에서 사라짐 → 지나감 판단")
                        
                        let passed = lastItem
                        lastNearestRouteId = nil
                        lastNearestArrTime = nil
                        lastNearestItem = nil
                        
                        return (nil, true, passed)
                    }
                }
                return (nil, false, nil)
            }
            
            guard let nearest = filtered.min(by: { $0.arrtime < $1.arrtime }) else {
                return (nil, false, nil)
            }
            
            var didPass = false
            var passedBus: BusArrivalItem?
            
            if let lastTime = lastNearestArrTime,
               let lastItem = lastNearestItem {
                
                let jump = (lastTime <= 90 && nearest.arrtime >= 180)
                
                if jump {
                    didPass = true
                    passedBus = lastItem
                    print("[DEBUG] 도착 시간 점프로 지나감 감지")
                }
            }
            
            lastNearestRouteId = nearest.routeid
            lastNearestArrTime = nearest.arrtime
            lastNearestItem = nearest
            
            return (nearest, didPass, passedBus)
            
        } catch {
            print("[ERROR] \(error.localizedDescription)")
            return (nil, false, nil)
        }
    }
    
    
    // UI 업데이트
    private func updateUI(with item: BusArrivalItem) {
        let minutes = item.arrtime / 60
        let text = minutes < 1 ? "곧 도착" : "\(minutes)분 후"
        
        isArrivingSoon = minutes < 2
        nearestBusInfo = (busNo: cleanBusNumber(item.routeno), arrivalText: text)
    }
    
    
    // 버스 번호 정리
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
    
    
    // prepareRouteArrivalSummary — 추천 경로 화면에서 1회 호출
    func prepareRouteArrivalSummary(for busRouteNode: BusRouteNode) async -> BusArrivalItem? {
        
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ERROR] 도시코드를 찾을 수 없습니다.")
            return nil
        }
        
        guard let station = busRouteNode.stations.first else {
            print("[ERROR] 정류소 정보가 없습니다.")
            return nil
        }
        
        do {
            var nodeId = ""
            if let local = station.localStationId {
                nodeId = local
            } else {
                nodeId = try await busArrivalService.fetchNodeId(
                    cityCode: cityCode,
                    stationName: station.stationName
                )
            }
            
            print("[DEBUG] prepareRouteArrivalSummary nodeId 조회 성공: \(nodeId)")
            
            let arrivals = try await busArrivalService.fetchBusArrivalInfo(
                cityCode: cityCode,
                nodeId: nodeId
            )
            
            let filtered = arrivals.filter { arrival in
                busRouteNode.busNo.contains(cleanBusNumber(arrival.routeno))
            }
            
            if let nearest = filtered.min(by: { $0.arrtime < $1.arrtime }) {
                print("[DEBUG] 경로 추천: 가장 빨리 오는 버스 = \(nearest.routeno), \(nearest.arrtime)초")
                return nearest
            }
            
            print("[DEBUG] 경로 추천: 해당 노선 버스 없음")
            return nil
            
        } catch {
            print("[ERROR] \(error.localizedDescription)")
            return nil
        }
    }
}
