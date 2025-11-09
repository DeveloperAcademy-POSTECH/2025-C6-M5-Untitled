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
            print("[DEBUG] 추적할 버스 번호들: \(busRouteNode.busNo)")  // 🔍 디버깅용 추가
            
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
    
    func endManager() {
        stopAutoRefresh()
        nearestBusInfo = nil
        isArrivingSoon = false
        hasPassed = false
        lastPassedBusNo = nil
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
            // localStationId를 우선적으로 사용
            var nodeId = ""
            if let localStationId = firstStation.localStationId {
                nodeId = localStationId
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
            
            print("🚍 [BeforeRide] 추적할 버스 목록: \(busRouteNode.busNo)")
            
            // 선택한 경로의 버스만 필터링
            let filteredArrivals = arrivals.filter { arrival in
                let cleanedArrivalNo = cleanBusNumber(arrival.routeno)
                let isMatchingBus = busRouteNode.busNo.contains(cleanedArrivalNo)
                
                // 디버깅용 로그
                if !isMatchingBus {
                    print("[DEBUG] 필터링됨: \(cleanedArrivalNo)는 선택한 경로가 아님")
                }
                
                return isMatchingBus
            }
            
            // 필터링된 버스가 없으면 → 지나감 여부 먼저 체크
            if filteredArrivals.isEmpty {
                if let lastItem = lastNearestItem {
                    let lastBusNo = cleanBusNumber(lastItem.routeno)
                    if busRouteNode.busNo.contains(lastBusNo) {
                        print("[DEBUG] 이전 버스 지나감 감지(다음 버스 없음): \(lastBusNo)")
                        let passed = lastItem
                        
                        // RESET
                        lastNearestRouteId = nil
                        lastNearestArrTime = nil
                        lastNearestItem = nil
                        
                        return (nil, true, passed)
                    }
                }
                
                // 지나간 버스가 없으면 정상 종료
                print("[DEBUG] 선택한 경로(\(busRouteNode.busNo))의 버스가 현재 없음")
                return (nil, false, nil)
            }

            // 여기서부터는 기존처럼 nearest 찾기
            guard let nearest = filteredArrivals.min(by: { $0.arrtime < $1.arrtime }) else {
                return (nil, false, nil) // 도달할 일 거의 없음
            }
            
            print("[DEBUG] 선택한 경로 중 가장 가까운 버스: \(cleanBusNumber(nearest.routeno)), \(nearest.arrtime)초 후")
            
            // 지나간 버스 판단도 선택한 경로인지 확인
            var didPass = false
            var passedBus: BusArrivalItem?
            
            if let lastId = lastNearestRouteId,
               let lastTime = lastNearestArrTime,
               let lastItem = lastNearestItem {
                
                // 마지막 추적한 버스도 선택한 경로의 버스인지 확인
                let lastBusNo = cleanBusNumber(lastItem.routeno)
                if busRouteNode.busNo.contains(lastBusNo) {
                    // 버스 ID가 바뀌었거나, 시간 차이가 크면 지나간 것으로 판단
                    if lastId != nearest.routeid || (lastTime < 60 && nearest.arrtime > 180) {
                        didPass = true
                        passedBus = lastItem
                        print("[DEBUG] 버스 지나감 감지: \(lastBusNo)")
                    }
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
                    stationName: station.stationName
                )
            }
            print("[DEBUG] nodeId 조회 성공: \(nodeId)")
            
            let arrivals = try await busArrivalService.fetchBusArrivalInfo(
                cityCode: cityCode,
                nodeId: nodeId
            )
            
            // 선택한 경로의 버스만 필터링
            let filteredArrivals = arrivals.filter { arrival in
                let cleanedArrivalNo = cleanBusNumber(arrival.routeno)
                return busRouteNode.busNo.contains(cleanedArrivalNo)
            }
            
            if let nearest = filteredArrivals.min(by: { $0.arrtime < $1.arrtime }) {
                print("[DEBUG] 선택한 경로 중 가장 빨리 오는 버스: \(nearest.routeno), \(nearest.arrtime)초 후 도착")
                return nearest
            } else {
                print("[DEBUG] 선택한 경로의 버스가 도착 예정에 없음")
                return nil
            }
            
        } catch {
            print("[ERROR] \(error.localizedDescription)")
            return nil
        }
    }
}
