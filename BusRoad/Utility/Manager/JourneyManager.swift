import CoreLocation
import Combine
import Foundation

final class JourneyManager: ObservableObject {
    @Published var origin: LocationInfo?
    @Published var destination: LocationInfo?
    @Published var journeyList: [Journey]?      // 스와이프할 journey list
    @Published var selectedJourney: Journey?    // 최종 선택된 journey
    @Published var journeyIndex: Int?
    @Published var firstLoadedLocation: LocationInfo?   // 단 한 번만 사용
    @Published var firstLoadedLocationUsed: Bool = false
    
    static let shared = JourneyManager()    // singleton manager
    
    private let locationService = LocationService.shared
    
    private init() { }  // 무한 호출 방지
    
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
    
    func warmUpLocation() { // 첫뷰에서 단 한 번만 호출
        print("[DEBUG] warmUpLocation started")
        Task { @MainActor in
            do {
                // ✅ 타임아웃 늘림
                let loc = try await locationService.requestOneShotLocation(timeout: 10)
                self.firstLoadedLocation = LocationInfo(
                    name: "현위치",
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude
                )
                print("[DEBUG] warmUpLocation 성공")
            } catch {
                print("[DEBUG] warmUpLocation 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func useFirstLoadedLocation() { // 한 번만 씀
        if !firstLoadedLocationUsed {
            if let firstLoadedLocation {
                print("[DEBUG] firstLoadedLocation is used")
                setOrigin(firstLoadedLocation)
            } else {
                print("[DEBUG] firstLoadedLocation 없음 - requestOrigin 호출")
                requestOrigin()
            }
            self.firstLoadedLocationUsed = true  // 이제 쓸 일 없음
        }
    }
    
    func requestOrigin() {
        Task { @MainActor in
            do {
                // 캐시 우선 사용 (10분까지 허용)
                let loc = try await locationService.getQuickLocation(maxAge: 600)
                print("[DEBUG] 현재 위치 저장 (캐시 사용 가능)")
                self.setOrigin(
                    LocationInfo(
                        name: "현위치",
                        latitude: loc.coordinate.latitude,
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
        
        let journeys = filtered.compactMap { parseJourney($0) }
        
        let clusteredJourneys = clusterJourneys(journeys)   // 버스루트 같고 버스번호만 다르면 합치기
        
        let top3 = clusteredJourneys.prefix(3)  // 합친 루트 중에 3개만 모아보기
        
        self.journeyList = Array(top3)
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
                // 중간 도보이고, 양옆에 노드가 있으면 '완전 동일 정류장' 여부로 스킵
                if i > 0, i < subPaths.count - 1 {
                    let prev = subPaths[i - 1]
                    let next = subPaths[i + 1]
                    if isSameStopStrict(prev: prev, next: next) {
                        // 같은 정류장에서 환승 → 도보 노드 생성하지 않음
                        continue
                    }
                }
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
            let passStopList = sub["passStopList"] as? [String: Any],
            let stations = passStopList["stations"] as? [[String: Any]],
            let travelTime = sub["sectionTime"] as? Int
        else {
            return nil
        }
        
        let busNumbers = lanes.compactMap { lane -> String? in
            guard let busNo = lane["busNo"] as? String else { return nil }
            return cleanBusNumber(busNo) // cleanBusNumber 적용
        }
        let busIds = lanes.compactMap { $0["busID"] as? Int }
        
        // 만약 유효한 버스 번호가 하나도 없으면 nil 반환
        if busNumbers.isEmpty {
            print("[DEBUG] parseBusNode: lanes에 유효한 busNo가 없습니다.")
            return nil
        }
        
        // stations 정보 중 필요한 정보만 뽑아내기
        let stationsInfo: [BusStation] = stations.compactMap { dict in
            guard
                let index = dict["index"] as? Int,
                let stationId = dict["stationID"] as? Int,
                let stationName = dict["stationName"] as? String,
                let stationCityCode = dict["stationCityCode"] as? Int,
                let arsId = dict["arsID"] as? String,
                let xString = dict["x"] as? String,
                let yString = dict["y"] as? String,
                let longitude = Double(xString),
                let latitude = Double(yString)
            else {
                return nil
            }
            
            let localStationId = dict["localStationID"] as? String
            
            return BusStation(index: index,
                              stationId: stationId,
                              stationName: stationName,
                              stationCityCode: stationCityCode,
                              localStationId: localStationId,
                              nodeId: arsId,
                              latitude: latitude,
                              longitude: longitude
            )
        }
        
        return BusRouteNode(
            start: LocationInfo(name: startName, latitude: startY, longitude: startX),
            end: LocationInfo(name: endName, latitude: endY, longitude: endX),
            busNo: busNumbers,    // 버스 번호만 추출
            busId: busIds,
            stations: stationsInfo,
            travelTime: travelTime
        )
    }
    
    private func cleanBusNumber(_ busNo: String) -> String {
        var result = busNo
        let pattern = #"\((?!\d+\))[^)]*\)"#
          result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)

          // 공백 정리
          result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                         .trimmingCharacters(in: .whitespacesAndNewlines)

          // 짝 불일치 괄호 제거
          let opens  = result.filter { $0 == "(" }.count
          let closes = result.filter { $0 == ")" }.count
          if opens != closes {
              // 짝이 안 맞으면 괄호 전부 제거
              result.removeAll { $0 == "(" || $0 == ")" }
          } else {
              // 짝은 맞지만, 예: "100)" 처럼 여는 괄호가 전혀 없는데 닫는 괄호로 끝나는 경우 방지
              if result.hasSuffix(")") && !result.contains("(") {
                  result.removeLast()
              }
          }
        
        // 숫자로 끝날 경우 "번" 추가
        if let lastChar = result.last, lastChar.isNumber {
            result += "번"
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 이전 노드의 end와 다음 노드의 start가 이름/좌표 모두 '완전히 동일'한지 검사
    private func isSameStopStrict(prev: [String: Any], next: [String: Any]) -> Bool {
        guard
            let prevEndName = prev["endName"] as? String,
            let prevEndX = prev["endX"] as? Double,
            let prevEndY = prev["endY"] as? Double,
            let nextStartName = next["startName"] as? String,
            let nextStartX = next["startX"] as? Double,
            let nextStartY = next["startY"] as? Double
        else { return false }
        
        return prevEndName == nextStartName &&
        prevEndX == nextStartX &&
        prevEndY == nextStartY
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
    
    func clusterJourneys(_ journeys: [Journey]) -> [Journey] {
        var clusters: [String: Journey] = [:]
        var order: [String] = []  // 입력 순서 유지용
        
        for journey in journeys {
            // 시그니처: 정류장 ID 기반으로
            let signature = journey.nodes.compactMap { node -> String? in
                switch node {
                case .bus(let b):
                    let ids = b.stations.map { String($0.stationId) }
                    return ids.joined(separator: ",")
                case .walk:
                    return nil
                }
            }.joined(separator: "|") // 여러 버스 구간은 '|'로 구분
            
            // 이미 같은 경로가 있는 경우 → 병합
            if var existing = clusters[signature] {
                let mergedNodes = zip(existing.nodes, journey.nodes).map { (lhs, rhs) -> RouteNode in
                    switch (lhs, rhs) {
                    case let (.bus(b1), .bus(b2)):
                        var merged = b1
                        
                        // busNo와 busId를 (no, id) 쌍으로 묶어서 병합
                        let pairs1 = Array(zip(b1.busNo, b1.busId))
                        let pairs2 = Array(zip(b2.busNo, b2.busId))
                        
                        // 중복 제거 (Set은 순서 없으므로 Dictionary 기반 중복 제거)
                        var mergedDict: [String: Int] = [:]
                        for (no, id) in pairs1 + pairs2 {
                            if mergedDict[no] == nil { // 첫 등장한 순서 유지
                                mergedDict[no] = id
                            }
                        }
                        
                        // 다시 배열로 복원 (순서 유지)
                        merged.busNo = Array(mergedDict.keys)
                        merged.busId = Array(mergedDict.values)
                        
                        return .bus(merged)
                    default:
                        return lhs
                    }
                }
                
                existing.nodes = mergedNodes
                clusters[signature] = existing
            } else {
                // 처음 본 경로
                clusters[signature] = journey
                order.append(signature)
            }
        }
        
        // 입력 순서 유지하여 반환
        return order.compactMap { clusters[$0] }
    }
    
    
}
