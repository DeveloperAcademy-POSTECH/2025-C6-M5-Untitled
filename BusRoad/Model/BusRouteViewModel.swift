//
//  BusRouteViewModel.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import Foundation
import Combine

class BusRouteViewModel: ObservableObject {
  @Published var routes: [BusRoute] = []
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?
  
  func fetchRoute() {
    isLoading = true
    errorMessage = nil
    
    guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: filePath),
          let apiKey = plist["ODSAY_API_KEY"] as? String else {
      fatalError("❌ API Key 로드 실패")
    }
    let urlString = "https://api.odsay.com/v1/api/searchPubTransPath"
    
    // 여기 출발지, 목적지 정보 - 경도 위도로 가져와서 검색하도록 수정해야 함
    let params: [String: Any] = [
      "SX": 129.3264,
      "SY": 36.01523,
      "EX": 129.3420,
      "EY": 36.07181,
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
        do {
          if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
             let result = json["result"] as? [String: Any],
             let path = result["path"] as? [[String: Any]] {
            
            var newRoutes: [BusRoute] = []
            
            for firstPath in path.prefix(3) {
              if let info = firstPath["info"] as? [String: Any],
                 let totalTimeMin = info["totalTime"] as? Int,
                 let subPathArr = firstPath["subPath"] as? [[String: Any]] {
                
                var busNos: [String] = []
                var stationGroupsLocal: [[String]] = []
                
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
                
                var boardingLocation = ""
                if let firstStationGroup = stationGroupsLocal.first,
                   let firstStation = firstStationGroup.first {
                  boardingLocation = firstStation
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "HH:mm"
                let currentDate = Date()
                let estimatedArrivalTime: String
                if let arrivalDate = Calendar.current.date(byAdding: .minute, value: totalTimeMin, to: currentDate) {
                    estimatedArrivalTime = dateFormatter.string(from: arrivalDate)
                } else {
                    // Fallback: use current time if adding minutes failed for any reason
                    estimatedArrivalTime = dateFormatter.string(from: currentDate)
                }

                let route = BusRoute(busNumbers: busNos, stationGroups: stationGroupsLocal, totalTime: totalTimeMin, estimatedArrivalTime: estimatedArrivalTime, boardingLocation: boardingLocation)
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
