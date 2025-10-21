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
    private let searchManager: SearchManager
    private var bag = Set<AnyCancellable>()
    
    init(journeyManager: JourneyManager = .shared, searchManager: SearchManager = .shared) {
        self.journeyManager = journeyManager
        self.searchManager = searchManager
        observeManager()
    }
    
    private func observeManager() {
        journeyManager.$origin
            .assign(to: &$origin)
        
        journeyManager.$destination
            .assign(to: &$destination)
        
        journeyManager.$journeyList
            .assign(to: &$routes)
        
        // MainSearchViewModel과 같은 형식으로 query 프록시 제공하기 위함
        searchManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }
    
    // MARK: 프록시
    var query: String {
        get { searchManager.query }
        set { searchManager.query = newValue }
    }
    var results: [NaverLocalItem] { searchManager.results }
    var shouldShowSearchMode: Bool { searchManager.shouldShowSearchMode }
    var isSearchLoading: Bool { searchManager.isLoading }
    var searchErrorMessage: String? { searchManager.errorMessage }
    var hasSubmitted:Bool {searchManager.hasSubmitted}
    
    func search() async { await searchManager.search() }
    func resetSearchMode() { searchManager.resetSearchMode() }
    
    func setDestination(destination: LocationInfo) {
        journeyManager.setDestination(destination)
    }
    func setOrigin(origin: LocationInfo) {
        journeyManager.setOrigin(origin)
    }
    
    func resetManager() {
        searchManager.reset()
    }
    
    // MARK: function
    func validateAndFetchRoute(origin: LocationInfo?, destination: LocationInfo?) {
        guard let origin = origin, let destination = destination else {
            print("[DEBUG] 출발지/목적지가 아직 설정되지 않았습니다.")
            return
        }
        
        let distanceInMeters = origin.asCLLocation.distance(from: destination.asCLLocation)
        
        // 거리가 700m 미만이면 API를 호출하지 않고 에러 메시지를 설정
        if distanceInMeters < 700 {
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
        print("[DEBUG] fetchRoute start")
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
            "EY": endY
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
                        
                        // API 서버 에러 처리
                        if let errorInfo = json["error"] as? [String: Any] {
                            let code = errorInfo["code"] as? String
                            let serverMessage = errorInfo["msg"] as? String ?? "알 수 없는 오류가 발생했습니다."
                            
                            switch code {
                            case "-98":
                                if let origin = self.origin, let destination = self.destination {
                                    let distance = origin.asCLLocation.distance(from: destination.asCLLocation)
                                    if distance > 30000 {
                                        self.errorMessage = "지원하지 않는 교통수단이 포함되어 있습니다."
                                        self.routes = []
                                        return
                                    }
                                }
                                self.errorMessage = "검색 결과가 없습니다."
                            case "500":
                                self.errorMessage = "출발지 또는 목적지 주변에 정류장이 없습니다."
                            default:
                                self.errorMessage = serverMessage
                            }
                            self.routes = []
                            return
                        }
                        
                        // 결과 처리
                        if let result = json["result"] as? [String: Any] {
                            
                            if let path = result["path"] as? [[String: Any]], !path.isEmpty {
                                for route in path {
                                    if let subPaths = route["subPath"] as? [[String: Any]] {
                                        for sub in subPaths {
                                            if let trafficType = sub["trafficType"] as? Int,
                                               trafficType >= 4 {
                                                self.errorMessage = "지원하지 않는 교통수단이 포함되어 있습니다."
                                                self.routes = []
                                                return
                                            }
                                        }
                                    }
                                }
                                
                                let busCount = result["busCount"] as? Int ?? 0
                                if busCount > 0 {
                                    self.journeyManager.setJourneyList(path)
                                } else {
                                    self.errorMessage = "표시할 수 있는 경로가 없습니다."
                                    self.routes = []
                                }
                                
                            } else {
                                let hasUnsupportedTransport =
                                ((result["trainRequest"] as? [String: Any])?["count"] as? Int ?? 0) > 0 ||
                                ((result["exBusRequest"] as? [String: Any])?["count"] as? Int ?? 0) > 0 ||
                                ((result["outBusRequest"] as? [String: Any])?["count"] as? Int ?? 0) > 0 ||
                                ((result["airRequest"] as? [String: Any])?["count"] as? Int ?? 0) > 0
                                
                                if hasUnsupportedTransport {
                                    self.errorMessage = "지원하지 않는 교통수단이 포함되어 있습니다."
                                } else {
                                    self.errorMessage = "추천 경로를 찾을 수 없습니다."
                                }
                                self.routes = []
                            }
                            
                        } else {
                            self.errorMessage = "추천 경로를 찾을 수 없습니다."
                            self.routes = []
                        }
                        
                    }
                }catch {
                    self.errorMessage = "데이터 처리 중 오류가 발생했습니다."
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
            guard index >= 0 && index < routes.count else {
                print("[ERROR] Index out of bounds in selectJourney")
                return
            }
            journeyManager.selectedJourney = routes[index]
            journeyManager.journeyIndex = 0
        }
    }
}

extension BusRouteViewModel {
    func createWalkingJourneyIfNeeded() {
        guard let origin = origin, let destination = destination else { return }
        
        let walkingNode = WalkRouteNode(
            start: origin,
            end: destination,
            travelTime: Int(origin.asCLLocation.distance(from: destination.asCLLocation) / 1.3)
        )
        
        let walkingJourney = Journey(
            totalTime: walkingNode.travelTime / 60, // 분 단위
            nodes: [.walk(walkingNode)]
        )
        
        // JourneyManager에 직접 등록
        JourneyManager.shared.journeyList = [walkingJourney]
        JourneyManager.shared.selectedJourney = walkingJourney
        JourneyManager.shared.journeyIndex = 0
        print("도보 경로 Journey 생성 완료")
    }
}
