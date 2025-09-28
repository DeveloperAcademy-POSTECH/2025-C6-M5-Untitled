import Foundation
import Combine

class BusRouteViewModel: ObservableObject {
  @Published var routes: [BusRoute] = []
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?
  
  func validateAndFetchRoute(origin: LocationInfo?, destination: LocationInfo?) {
    if let origin = origin, let destination = destination {
      print("➡️ ViewModel: 출발지/목적지 준비 완료! 경로 검색을 시작합니다.")
      // 유효성이 확인되면, 실제 API를 호출하는 private 함수를 실행합니다.
      fetchRoute(
        startX: origin.longitude,
        startY: origin.latitude,
        endX: destination.longitude,
        endY: destination.latitude
      )
    }
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
    
    odsayAPI(apiKey: apiKey, urlString: urlString, params: params) { success, ret in
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
          if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
             let result = json["result"] as? [String: Any],
             let path = result["path"] as? [[String: Any]] {
            
            var newRoutes: [BusRoute] = []
            
            for firstPath in path.prefix(3) {
              if let info = firstPath["info"] as? [String: Any],
                 let totalTimeMin = info["totalTime"] as? Int,
                 let originName = info["firstStartStation"] as? String,
                 let destinationName = info["lastEndStation"] as? String,
                 let subPathArr = firstPath["subPath"] as? [[String: Any]] {
                
                var busNos: [String] = []
                var stationGroupsLocal: [[String]] = []
                var boardingLocation = ""
                if let firstBusPath = subPathArr.first(where: { ($0["trafficType"] as? Int) == 2 }),
                   let startName = firstBusPath["startName"] as? String {
                  boardingLocation = startName
                }
                
                
                for sub in subPathArr {
                  if let trafficType = sub["trafficType"] as? Int, trafficType == 2 {
                    if let lane = sub["lane"] as? [[String: Any]],
                       let busNumber = lane.first?["busNo"] as? String {
                      let numericBusNumber = busNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                      busNos.append(numericBusNumber)
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
            self.errorMessage = "JSON 구조가 예상과 다름"
          }
        } catch {
          self.errorMessage = "JSON 파싱 실패: \(error.localizedDescription)"
        }
      }
    }
  }
}
