// BusRouteViewModel.swift

import Foundation
import Combine
import CoreLocation
import SwiftUI

extension LocationInfo {
    var asCLLocation: CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
}


class BusRouteViewModel: ObservableObject {
    @Published var routes: [Journey]?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var origin: LocationInfo?
    @Published var destination: LocationInfo?
    @Published var isSearching: Bool = false
    
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
        
        journeyManager.$journeyList
            .assign(to: &$routes)
    }
    
    func validateAndFetchRoute(origin: LocationInfo?, destination: LocationInfo?) {
        guard let origin = origin, let destination = destination else {
            print("[DEBUG] 출발지/목적지가 아직 설정되지 않았습니다.")
            return
        }
        
        let distanceInMeters = origin.asCLLocation.distance(from: destination.asCLLocation)
        
        // 거리가 500m 미만이면 API를 호출하지 않고 에러 메시지를 설정
        if distanceInMeters < 500 {
            print("🚨 거리가 너무 가까워 API를 호출하지 않습니다.")
            self.errorMessage = "출발지와 목적지가 너무 가깝습니다."
            self.routes = []
            return
        }
        print("➡️ ViewModel: 출발지/목적지 준비 완료! 경로 검색을 시작합니다.")
        
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
        
        // SearchType: 0(최적), 1(최소환승), 2(최소시간)
        let searchTypes = [0, 1, 2]
        let routeTypeNames = ["추천", "최소환승", "최소시간"]
        
        guard let odsayService = ODsayAPIService(apiKey: apiKey) as? ODsayAPIService else {
            self.isLoading = false
            self.errorMessage = "ODsay 서비스 초기화 실패"
            return
        }
        
        var finalJourneys: [Journey?] = Array(repeating: nil, count: searchTypes.count)
        var completedRequests = 0
        var anyErrorOccurred = false
        
        for (index, searchType) in searchTypes.enumerated() {
            let params: [String: Any] = [
                "SX": startX,
                "SY": startY,
                "EX": endX,
                "EY": endY,
                "SearchType": searchType // 이 파라미터로 필터링된 결과가 반환됨
            ]
            
            odsayService.request(urlString: urlString, params: params) { success, ret in
                DispatchQueue.main.async {
                    completedRequests += 1
                    
                    if !success {
                        anyErrorOccurred = true
                    } else {
                        guard let data = ret as? Data else {
                            anyErrorOccurred = true
                            return
                        }
                        
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                
                                // API 서버 에러 체크
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
                                    anyErrorOccurred = true
                                    return
                                }
                                
                                // 정상 경로 데이터 추출 및 파싱
                                if let result = json["result"] as? [String: Any],
                                   let path = result["path"] as? [[String: Any]],
                                   let bestPath = path.first, // SearchType에 해당하는 가장 좋은 경로(첫 번째)만 선택
                                   let pathType = bestPath["pathType"] as? Int,
                                   pathType != 1 && pathType != 3 { // pathType 1(지하철), 3(버스+지하철)은 제외
                                    
                                    let label = routeTypeNames[index]
                                    // JourneyManager의 파싱 함수를 호출하고 라벨을 전달
                                    if let journey = self.journeyManager.parseJourney(bestPath, routeType: label) {
                                        finalJourneys[index] = journey // 해당 SearchType의 인덱스에 저장하여 순서 보장
                                    }
                                    
                                } else {
                                    print("[ALERT] 버스/복합 경로 없음 for SearchType \(searchType)")
                                }
                            } else {
                                anyErrorOccurred = true
                            }
                        } catch {
                            anyErrorOccurred = true
                            print("🚨 JSON 파싱 오류: \(error)")
                        }
                    }
                    
                    // 모든 요청이 완료되었을 때 최종 처리
                    if completedRequests == searchTypes.count {
                        self.isLoading = false
                        
                        // nil이 아닌 Journey만 필터링하여 최종 리스트 생성
                        let validJourneys = finalJourneys.compactMap { $0 }
                        
                        // JourneyManager에 최종 Journey 배열 전달
                        self.journeyManager.setJourneyList(journeys: validJourneys)
                        
                        if let finalRoutes = self.journeyManager.journeyList, !finalRoutes.isEmpty {
                            self.errorMessage = nil
                        } else {
                            // 경로를 하나도 찾지 못한 경우
                            self.errorMessage = self.errorMessage ?? "추천 경로를 찾을 수 없습니다."
                            self.routes = []
                        }
                    }
                }
            }
        }
    }
    
    func requestOrigin() {
        print("[DEBUG] requestOrigin started")
        journeyManager.requestOrigin()
        print("[DEBUG] requestOrigin finished")
    }
    
    func selectJourney(at index: Int) {
        if let routes = journeyManager.journeyList {
            // 인덱스 경계 확인
            guard index >= 0 && index < routes.count else {
                print("[ERROR] Index out of bounds in selectJourney")
                return
            }
            journeyManager.selectedJourney = routes[index]
            print("[DEBUG] selected journey: \(routes[index])")
        }
    }
}
