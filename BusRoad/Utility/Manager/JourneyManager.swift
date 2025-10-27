import CoreLocation
import Combine
import Foundation

final class JourneyManager: ObservableObject {
    // TODO: 변수 순서 컨벤션 맞춰서 조정하기
    @Published var origin: LocationInfo?
    @Published var destination: LocationInfo?
    @Published var journeyList: [Journey]?      // 스와이프할 journey list
    @Published var selectedJourney: Journey?    // 최종 선택된 journey
    @Published var journeyIndex: Int?
    
    static let shared = JourneyManager()    // singleton manager
    
    let locationService = LocationService()
    
    func reset() {
        self.origin = nil
        self.destination = nil
        self.journeyList = nil
        self.selectedJourney = nil
        self.journeyIndex = nil
    }
    
    func setOrigin(_ origin: LocationInfo) {
        self.origin = origin
    }
    
    func setDestination(_ destination: LocationInfo) {
        self.destination = destination
    }
    
    func requestOrigin() {
        Task { @MainActor in
            do {
                let loc = try await locationService.requestOneShotLocation()
                print("[DEBUG] 현재 위치 저장")
                self.setOrigin(
                    LocationInfo(
                        name: "현위치",
                        latitude:  loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude
                    )
                )
            } catch {
                print("[DEBUG] 위치 요청 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func setJourneyList(_ path: [[String: Any]]) {
        // pathType: 1-지하철, 2-버스, 3-버스+지하철
        
        // MARK: 버스 경로만 모아보기(지하철 확장하면 고려해서 코드 전체 수정하기)
        let filtered = path.filter { $0["pathType"] as? Int == 2 }
        
        let top3 = filtered.prefix(3)
        
        self.journeyList = top3.compactMap { parseJourney($0) }
    }
    
    public func parseJourney(_ data: [String: Any]) -> Journey? {
        guard let subPaths = data["subPath"] as? [[String: Any]],
              let info = data["info"] as? [String: Any],
              let totalTime = info["totalTime"] as? Int
        else { return nil }
        
        var nodes: [RouteNode] = []
        
        for (i, sub) in subPaths.enumerated() {
            let tType = sub["trafficType"] as? Int
            // trafficType: 이동 수단 종류 (1-지하철, 2-버스, 3-도보)
            switch tType {
            case 1: // TODO: 지하철
                continue
                
            case 2: // 버스
                if let bus = parseBusNode(sub) {
                    nodes.append(.bus(bus))
                }
                
            case 3: // 도보
                if let walk = parseWalkNode(at: i, in: subPaths) {
                    nodes.append(.walk(walk))
                }
                
            default:
                print("[DEBUG] 알 수 없는 교통 타입: \(String(describing: tType))")
                continue
            }
        }
        return Journey(totalTime: totalTime, nodes: nodes)
    }
    
    private func parseBusNode(_ sub: [String: Any]) -> BusRouteNode? {
        // 필수 데이터
        guard
            let startX = sub["startX"] as? Double,
            let startY = sub["startY"] as? Double,
            let endX = sub["endX"] as? Double,
            let endY = sub["endY"] as? Double,
            let startName = sub["startName"] as? String,
            let endName = sub["endName"] as? String,
            let lanes = sub["lane"] as? [[String: Any]],
            let lane = lanes.first,
            let busNo = lane["busNo"] as? String,
            let busId = lane["busID"] as? Int,
            let passStopList = sub["passStopList"] as? [String: Any],
            let stations = passStopList["stations"] as? [[String: Any]],
            let travelTime = sub["sectionTime"] as? Int
        else {
            return nil
        }
        
        // busNo에서 괄호()로 묶인 불필요한 정보 없애기
        let cleanedBusNo = cleanBusNumber(busNo)
        
        // stations 정보 중 필요한 정보만 뽑아내기
        let stationsInfo: [BusStation] = stations.compactMap { dict in
            guard
                let index = dict["index"] as? Int,
                let stationId = dict["stationID"] as? Int,
                let stationName = dict["stationName"] as? String,
                let stationCityCode = dict["stationCityCode"] as? Int
            else {
                return nil
            }
            
            let localStationId = dict["localStationID"] as? String
            
            return BusStation(index: index,
                              stationId: stationId,
                              stationName: stationName,
                              stationCityCode: stationCityCode,
                              localStationId: localStationId
            )
        }
        
        return BusRouteNode(
            start: LocationInfo(name: startName, latitude: startY, longitude: startX),
            end: LocationInfo(name: endName, latitude: endY, longitude: endX),
            busNo: cleanedBusNo,    // 버스 번호만 추출
            busId: busId,
            stations: stationsInfo,
            travelTime: travelTime
        )
    }
    
    private func cleanBusNumber(_ busNo: String) -> String {
        var result = busNo
        let pattern = #"\([^()]*\)"#  // 한 단계 괄호 제거용 정규식
        
        // 안쪽 괄호부터 반복 제거
        while let _ = result.range(of: pattern, options: .regularExpression) {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 숫자로 끝날 경우 "번" 추가
        if let lastChar = result.last, lastChar.isNumber {
            result += "번"
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseWalkNode(at index: Int, in subPath: [[String: Any]]) -> WalkRouteNode? {
        // 처음 노드가 도보인 경우: 다음 노드에서 startInfo 가져와서 도보노드의 endInfo로 등록하기
        if index == 0 && subPath.count > 1 {
            // 현재 노드
            let currentNode = subPath[index]
            let nextNode = subPath[index+1]
            guard
                let endName = nextNode["startName"] as? String,
                let endX = nextNode["startX"] as? Double,
                let endY = nextNode["startY"] as? Double,
                let travelTime = currentNode["sectionTime"] as? Int // [주의] 이것만 '현재 노드'
            else { return nil }
            if let origin = self.origin {
                return WalkRouteNode(
                    start: origin,
                    end: LocationInfo(name: endName, latitude: endY, longitude: endX),
                    travelTime: travelTime
                )
            }
            
        } else if index == subPath.count - 1 && subPath.count > 1 {  // 맨끝 노드가 도보인 경우: 이전 노드에서 endInfo 가져와서 startInfo로 등록하기
            let currentNode = subPath[index]
            let prevNode = subPath[index-1]
            guard
                let startName = prevNode["endName"] as? String,
                let startX = prevNode["endX"] as? Double,
                let startY = prevNode["endY"] as? Double,
                let travelTime = currentNode["sectionTime"] as? Int
            else { return nil }
            
            if let destination = self.destination {
                return WalkRouteNode(
                    start: LocationInfo(name: startName, latitude: startY, longitude: startX),
                    end: destination,
                    travelTime: travelTime
                )
            }
        } else if subPath.count == 1 {  // (혹시나) 도보 경로밖에 존재하지 않을 때: 출발지, 목적지로 등록하기
            let currentNode = subPath[index]
            guard let travelTime = currentNode["sectionTime"] as? Int else { return nil }
            
            if let origin = self.origin, let destination = self.destination {
                return WalkRouteNode(
                    start: origin,
                    end: destination,
                    travelTime: travelTime
                )
            }
        } else {    // 중간 노드가 도보인 경우: 이전, 다음 노드에서 각각 endInfo, startInfo 가져와서 startInfo, endInfo로 등록하기
            let prevNode = subPath[index-1]
            let currentNode = subPath[index]
            let nextNode = subPath[index+1]
            guard
                let startName = prevNode["endName"] as? String,
                let startX = prevNode["endX"] as? Double,
                let startY = prevNode["endY"] as? Double,
                let endName = nextNode["startName"] as? String,
                let endX = nextNode["startX"] as? Double,
                let endY = nextNode["startY"] as? Double,
                let travelTime = currentNode["sectionTime"] as? Int
            else { return nil }
            
            return WalkRouteNode(
                start: LocationInfo(name: startName, latitude: startY, longitude: startX),
                end: LocationInfo(name: endName, latitude: endY, longitude: endX),
                travelTime: travelTime
            )
        }
        return nil
    }
}
