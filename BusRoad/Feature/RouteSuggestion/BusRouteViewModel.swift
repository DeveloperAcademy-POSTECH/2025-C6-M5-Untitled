import Foundation
import Combine
import CoreLocation

extension LocationInfo {
  var asCLLocation: CLLocation {
    return CLLocation(latitude: self.latitude, longitude: self.longitude)
  }
}

class BusRouteViewModel: ObservableObject {
    @Published var routes: [BusRoute] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var origin: LocationInfo?
    @Published var destination: LocationInfo?
    
    private let journeyManager: JourneyManager
    
    init(manager: JourneyManager = .shared) {
        self.journeyManager = manager
        observeManager()
    }
    
    private func observeManager() {
        journeyManager.$origin
            .assign(to: &$origin)

        journeyManager.$destination
            .assign(to: &$destination)

    }
    
    func validateAndFetchRoute(origin: LocationInfo?, destination: LocationInfo?) {
        guard let origin = origin, let destination = destination else {
            // 아직 출발지나 목적지가 설정되지 않은 상태이므로 아무것도 하지 않음
            print("[DEBUG] 출발지/목적지가 아직 설정되지 않았습니다.")
            return
        }
        
        let distanceInMeters = origin.asCLLocation.distance(from: destination.asCLLocation)
        
        // 거리가 500m 미만이면 API를 호출하지 않고 에러 메시지를 설정
        if distanceInMeters < 500 {
            print("🚨 거리가 너무 가까워 API를 호출하지 않습니다.")
            self.errorMessage = "출발지와 목적지가 너무 가깝습니다."
            self.routes = [] // 기존 경로가 있다면 비워줌
            return
        }
        print("➡️ ViewModel: 출발지/목적지 준비 완료! 경로 검색을 시작합니다.")
        // 유효성이 확인되면, 실제 API를 호출하는 private 함수를 실행
        fetchRoute(
            startX: origin.longitude,
            startY: origin.latitude,
            endX: destination.longitude,
            endY: destination.latitude
        )
        print("[DEBUG] Route 준비 완료!")
    }
    
    private func fetchRoute(startX: Double, startY: Double, endX: Double, endY: Double) {
        isLoading = true
        errorMessage = nil
        
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let apiKey = plist["ODSAY_API_KEY"] as? String else {
            self.isLoading = false
            self.errorMessage = "API Key 로드 실패"
            return
        }
        let urlString = "https://api.odsay.com/v1/api/searchPubTransPath"
        
        let params: [String: Any] = [
            "SX": startX,
            "SY": startY,
            "EX": endX,
            "EY": endY,
            "SearchType": 0
        ]
        
        let odsayService = ODsayAPIService(apiKey: apiKey)
        
        odsayService.request(urlString: urlString, params: params) { success, ret in
            DispatchQueue.main.async {
                self.isLoading = false
                if !success {
                    self.errorMessage = "API 호출 실패"
                    return
                }
                guard let data = ret as? Data else {
                    self.errorMessage = "읽을 데이터 없음"
                    return
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📬 [ODsay API 응답 원본]")
                    print(jsonString)
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // API 서버가 보낸 에러가 있는지 먼저 확인
                        if let errorInfo = json["error"] as? [String: Any] {
                            let code = errorInfo["code"] as? String
                            let serverMessage = errorInfo["msg"] as? String ?? "알 수 없는 오류가 발생했습니다."
                            
                            switch code {
                            case "-98":
                                self.errorMessage = "검색 결과가 없습니다."
                            case "500":
                                self.errorMessage = "출발지 또는 목적지 주변에 정류장이 없습니다."
                            default:
                                self.errorMessage = serverMessage
                            }
                            self.routes = [] // 기존 경로 비워주기
                            return
                        }
                        
                        if let result = json["result"] as? [String: Any],
                           let path = result["path"] as? [[String: Any]],
                           !path.isEmpty {
                            
                            var newRoutes: [BusRoute] = []
                            for firstPath in path.prefix(3) {
                                if let info = firstPath["info"] as? [String: Any],
                                   let totalTimeMin = info["totalTime"] as? Int,
                                   let originName = info["firstStartStation"] as? String,
                                   let destinationName = info["lastEndStation"] as? String,
                                   let subPathArr = firstPath["subPath"] as? [[String: Any]] {
                                    
                                    // (이하 버스 번호, 정류장 등 파싱 로직은 기존과 동일)
                                    var busNos: [String] = []
                                    var stationGroupsLocal: [[String]] = []
                                    var boardingLocation = ""
                                    if let firstBusPath = subPathArr.first(where: { ($0["trafficType"] as? Int) == 2 }),
                                       let startName = firstBusPath["startName"] as? String {
                                        boardingLocation = startName
                                    }
                                    
                                    for sub in subPathArr {
                                        if let trafficType = sub["trafficType"] as? Int, trafficType == 2 {
                                            if let laneArray = sub["lane"] as? [[String: Any]] {
                                                for laneInfo in laneArray {
                                                    if let busNumber = laneInfo["busNo"] as? String {
                                                        let numericBusNumber = busNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                                        busNos.append(numericBusNumber)
                                                    }
                                                }
                                            }
                                            var thisBusStations: [String] = []
                                            if let passStopList = sub["passStopList"] as? [String: Any],
                                               let stationsArr = passStopList["stations"] as? [[String: Any]] {
                                                for st in stationsArr {
                                                    if let name = st["stationName"] as? String {
                                                        thisBusStations.append(name)
                                                    }
                                                }
                                            }
                                            stationGroupsLocal.append(thisBusStations)
                                        }
                                    }
                                    
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "HH:mm"
                                    let currentDate = Date()
                                    let estimatedArrivalTime: String
                                    if let arrivalDate = Calendar.current.date(byAdding: .minute, value: totalTimeMin, to: currentDate) {
                                        estimatedArrivalTime = dateFormatter.string(from: arrivalDate)
                                    } else {
                                        estimatedArrivalTime = dateFormatter.string(from: currentDate)
                                    }
                                    
                                    let route = BusRoute(
                                        origin: originName,
                                        destination: destinationName,
                                        busNumbers: busNos,
                                        stationGroups: stationGroupsLocal,
                                        totalTime: totalTimeMin,
                                        estimatedArrivalTime: estimatedArrivalTime,
                                        boardingLocation: boardingLocation
                                    )
                                    newRoutes.append(route)
                                }
                            }
                            self.routes = newRoutes
                            
                        } else {
                            self.errorMessage = "추천 경로를 찾을 수 없습니다."
                            self.routes = []
                        }
                    }
                } catch {
                    self.errorMessage = "데이터 처리 중 오류가 발생했습니다."
                }
            }
        }
    }
    
    func requestOrigin() {
        print("[DEBUG] requestOrigin")
        journeyManager.requestOrigin()
    }
}
