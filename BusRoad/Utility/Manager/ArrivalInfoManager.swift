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
    
    private init(busArrivalService: BusArrivalService? = nil) {
        self.busArrivalService = busArrivalService ?? BusArrivalService()
    }
    
    // (경로추천뷰 한번호출) 경로 journey -> 정류소ID, 버스리스트(No, Id), 그중 가장 도착시간 짧은 버스No와 남은시간(초)(BusArrivalItem)
    func prepareRouteArrivalSummary(_ journey: Journey) async -> BusArrivalItem? {
        guard let busRouteNode = journey.firstBusRoute else {
            return nil
        }
        
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ERROR] 도시코드를 찾을 수 없습니다.")
            return nil
        }
        
        print("[DEBUG] 도시코드: \(cityCode)")
        
        let station = busRouteNode.stations[0]
        
        do {
            let nodeId = try await busArrivalService.fetchNodeId(
                cityCode: cityCode,
                stationName: station.stationName,
                arsId: station.nodeId
            )
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
    
    // (승차전뷰 새로고침 시 API 호출) 버스루트노드 -> 가장 도착 가까운 버스의 BusArrivalTime
    func refreshNearestBusArrival(for busRouteNode: BusRouteNode) async -> BusArrivalItem? {
        let busLocation = busRouteNode.start
        
        guard let cityCode = await CityCodeManager.shared.getCityCodeByLocationAsync(
            latitude: busLocation.latitude,
            longitude: busLocation.longitude
        ) else {
            print("[ERROR] 도시코드를 찾을 수 없습니다.")
            return nil
        }
        
        print("[DEBUG] 도시코드: \(cityCode)")
        
        guard let firstStation = busRouteNode.stations.first else {
            print("[ERROR] 정류소 정보가 없습니다.")
            return nil
        }
        
        do {
            let nodeId = try await busArrivalService.fetchNodeId(
                cityCode: cityCode,
                stationName: firstStation.stationName,
                arsId: firstStation.nodeId
            )
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
