import Foundation
import Combine
import CoreLocation
import SwiftUI

@MainActor
class BusRouteViewModel: ObservableObject {
    
    // 경로 설정 관련
    @Published var routes: [Journey]?
    @Published var currentIndex: Int = 0
    
    // 출발지, 목적지 값 관련
    @Published var origin: LocationInfo?
    @Published var destination: LocationInfo?
    @Published var userDidSelectOrigin: Bool = false
    @Published var isFirstLoad = true
    @Published var locationType: LocationType = .origin
    @Published var totalDistance: Double = 0.0
    
    //버스 도착 시간 관련
    @Published var arrivalText: String? = nil
    
    // 에러 케이스 분류용
    @Published var errorMessage: String?
    
    //검색에 필요한 데이터
    @Published var hasSubmitted: Bool = false
    @Published var isSearchMode = false
    @Published var isLoading: Bool = false
    @Published var showDestinationMap: Bool = false
    @Published var isRefreshingLocation: Bool = false
    @Published var store = LocationStore()
    
    
    private let journeyManager: JourneyManager
    private let searchManager: SearchManager
    private let arrivalInfoManager: ArrivalInfoManager
    private var bag = Set<AnyCancellable>()
    
    init(journeyManager: JourneyManager = .shared, searchManager: SearchManager = .shared, arrivalInfoManager: ArrivalInfoManager = .shared) {
        self.journeyManager = journeyManager
        self.searchManager = searchManager
        self.arrivalInfoManager = arrivalInfoManager
        observeManager()
    }
    
    private func observeManager() {
        journeyManager.$origin
            .assign(to: &$origin)
        
        journeyManager.$destination
            .assign(to: &$destination)
        
        journeyManager.$journeyList
            .assign(to: &$routes)
        
        searchManager.$hasSubmitted
            .assign(to: &$hasSubmitted)
        
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
    
    var results: [PlaceSummary] { searchManager.results }
    var shouldShowSearchMode: Bool { searchManager.shouldShowSearchMode }
    var isSearchLoading: Bool { searchManager.isLoading }
    var searchErrorMessage: String? { searchManager.errorMessage }
    
    func search() async { await searchManager.search() }
    
    func resetSearchMode() { searchManager.resetSearchMode() }
    
    func setDestination(destination: LocationInfo) {
        journeyManager.setDestination(destination)
    }
    
    func setOrigin(origin: LocationInfo) {
        journeyManager.setOrigin(origin)
        userDidSelectOrigin = true
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
        
        // 목적지와 출발지가 같으면 API를 호출하지 않고 에러 메시지를 설정
        if origin.latitude == destination.latitude && origin.longitude == destination.longitude {
            print("🚨 출발지와 목적지가 동일해 API를 호출하지 않습니다.")
            self.errorMessage = "출발지와 도착지가 같습니다."
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
                                }
                                self.errorMessage = "출발지와 목적지가 너무 가깝습니다."
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
                } catch {
                    self.errorMessage = "데이터 처리 중 오류가 발생했습니다."
                }
            }
        }
    }
    
    func requestOrigin() {
        
        if userDidSelectOrigin {
            print("[DEBUG] 사용자가 출발지를 선택했으므로 현위치로 바꾸지 않습니다")
            return
        }
        
        print("[DEBUG] requestOrigin started")
        journeyManager.requestOrigin()
        print("[DEBUG] requestOrigin finished")
    }
    
    // 강제 새로고침 (캐시 무시)
    func forceRefreshOrigin() async {
        guard !isRefreshingLocation else {
            print("[DEBUG] 이미 새로고침 중입니다")
            return
        }
        
        isRefreshingLocation = true
        print("[DEBUG] 현위치 강제 새로고침 시작")
        
        let minimumDurationTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) 
        }
        
        do {
            let newLocation = try await LocationService.shared.forceRefreshLocation(timeout: 15)
            
            let locationInfo = LocationInfo(
                name: "현위치",
                latitude: newLocation.coordinate.latitude,
                longitude: newLocation.coordinate.longitude
            )
            
            setOrigin(origin: locationInfo)
            userDidSelectOrigin = false
            print("[DEBUG] 현위치 새로고침 완료")
            
        } catch LocationService.LocationError.timeout {
            print("현위치 새로고침 실패: 타임아웃")
            errorMessage = "위치 정보를 가져오는데 시간이 초과되었습니다."
            
        } catch LocationService.LocationError.authorizationDenied {
            print("현위치 새로고침 실패: 권한 거부")
            errorMessage = "위치 권한이 필요합니다."
            
        } catch LocationService.LocationError.busy {
            print("현위치 새로고침 실패: 이미 진행 중")
            errorMessage = "위치 정보를 가져오는 중입니다."
            
        } catch {
            print("현위치 새로고침 실패: \(error.localizedDescription)")
            errorMessage = "현위치를 가져올 수 없습니다."
        }
        
        // 최소 시간이 지날 때까지 대기
        await minimumDurationTask.value
        
        isRefreshingLocation = false
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
    
    func fetchFirstLoadedLocation() {
        journeyManager.useFirstLoadedLocation()
    }
}

extension BusRouteViewModel {
    func createWalkingJourneyIfNeeded() {
        guard let origin = origin, let destination = destination else { return }
        
        let distance = origin.asCLLocation.distance(from: destination.asCLLocation)
        totalDistance = distance
        
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

// MARK: - 검색과 관련된 메서드들
extension BusRouteViewModel {
    /// 검색 모드 종료
    func exitSearchMode() {
        query = ""
    }
    
    /// 검색 수행
    func performSearch() async {
        await search()
    }
    
    /// 검색어 초기화
    func clearQuery() {
        query = ""
    }
    
    /// 장소 선택 (출발지/목적지)
    func selectPlace(item: PlaceSummary, locationType: LocationType) {
        switch locationType {
        case .origin:
            setOrigin(origin: LocationInfo(
                name: item.name,
                latitude: item.latitude,
                longitude: item.longitude
            ))
        case .destination:
            setDestination(destination: LocationInfo(
                name: item.name,
                latitude: item.latitude,
                longitude: item.longitude
            ))
        }
        resetManager()
    }
    
    func fetchNearestBusInfo(for route: BusRouteNode) async -> (busNo: String, arrivalText: String)? {
        guard let item = await ArrivalInfoManager.shared.prepareRouteArrivalSummary(for: route) else {
            print("[DEBUG] 도착 정보 없음")
            return nil
        }
        
        let minutes = item.arrtime / 60
        let arrivalText: String
        if minutes < 1 {
            arrivalText = "곧 도착"
        } else {
            arrivalText = "\(minutes)분 후"
        }
        
        self.arrivalText = arrivalText
        print("버스 도착 예정 시간 업데이트 완료")
        
        let cleanedBusNo = cleanBusNumber(item.routeno)
        
        return (busNo: cleanedBusNo, arrivalText: arrivalText)
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
}

// MARK: - 음성 검색 관련 메서드들
extension BusRouteViewModel {
    /// 마이크 버튼 탭 → 풀스크린 뷰 열기
    func handleMicTap() {
        VoiceSearchManager.shared.present { [weak self] text in
            self?.handleVoiceSearchCompleted(text)
        }
    }
    
    /// 음성 검색 완료 → 쿼리 반영 + 검색 실행
    func handleVoiceSearchCompleted(_ text: String) {
        query = text
        isSearchMode = true
        Task {
            await search()
        }
    }
    
    /// 음성 검색 뷰에서 닫기
    func dismissVoiceSearch() {
        VoiceSearchManager.shared.dismiss()
    }
}
