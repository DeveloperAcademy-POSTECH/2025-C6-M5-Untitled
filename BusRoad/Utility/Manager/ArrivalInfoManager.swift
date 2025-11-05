//
//  ArrivalInfoManager.swift
//  BusRoad
//
//  Created by 박난 on 11/4/25.
//
import CoreLocation

class ArrivalInfoManager {
    static let shared = ArrivalInfoManager()
    
    private let busArrivalService: BusArrivalService
    
    private var refreshTask: Task<Void, Never>? = nil
    private var lastNearestRouteId: String? = nil
    private var lastNearestArrTime: Int? = nil
    private var lastNearestItem: BusArrivalItem?
    
    private init(busArrivalService: BusArrivalService? = nil) {
        self.busArrivalService = busArrivalService ?? BusArrivalService()
    }
    
    // MARK: - 실시간 갱신 시작
    func startAutoRefresh(for busRouteNode: BusRouteNode) {
        stopAutoRefresh() // 중복 방지
        
        refreshTask = Task {
            print("[DEBUG] ArrivalInfoManager: Auto Refresh Started")
            
            while !Task.isCancelled {
                do {
                    let (nearest, didPass, passedBus) = try await self.refreshNearestBusArrival(for: busRouteNode)
                    
                    if let nearest = nearest {
                        print("[DEBUG] 현재 최근 버스: \(nearest.routeno) (\(nearest.routeid)) \(nearest.arrtime)초 후 도착")
                        if didPass {
                            print("[DEBUG] 버스 지나감 감지됨 — routeId 변경 or 새로운 차량 감지")
                        }
                    }
                    
                    // 다음 호출까지 대기 (30초 또는 60초)
                    let delay = (nearest?.arrtime ?? 999) < 60 ? 30.0 : 60.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                } catch {
                    print("[ERROR] Auto refresh error: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                }
            }
        }
    }
    
    // MARK: - 갱신 중단
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        print("[DEBUG] ArrivalInfoManager: Auto Refresh Stopped")
    }
    
    // MARK: - 도착 정보 최신화 (결과 + 지나감 여부)
    // (승차전뷰 새로고침 시 API 호출) 버스루트노드 -> 가장 도착 가까운 버스의 BusArrivalTime
    func refreshNearestBusArrival(for busRouteNode: BusRouteNode)
        async -> (item: BusArrivalItem?, didPass: Bool, passedBus: BusArrivalItem?) {
        
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ERROR] 도시코드를 찾을 수 없습니다.")
            return (nil, false, nil)
        }
        
        guard let firstStation = busRouteNode.stations.first else {
            print("[ERROR] 정류소 정보가 없습니다.")
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

            // 지나감 판단 로직
            var didPass = false
            var passedBus: BusArrivalItem? = nil

            if let lastId = lastNearestRouteId, let lastTime = lastNearestArrTime {
                if lastId != nearest.routeid || (lastTime < 30 && nearest.arrtime > 90) {
                    didPass = true
                    passedBus = lastNearestItem // 바로 이전 버스
                }
            }

            // 상태 업데이트
            lastNearestRouteId = nearest.routeid
            lastNearestArrTime = nearest.arrtime
            lastNearestItem = nearest

            return (nearest, didPass, passedBus)

        } catch {
            print("[ERROR] \(error.localizedDescription)")
            return (nil, false, nil)
        }
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
