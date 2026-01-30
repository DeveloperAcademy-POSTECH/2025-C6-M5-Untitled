import Combine
import Foundation
import CoreLocation


@MainActor
final class SearchManager: ObservableObject {
    
    static let shared = SearchManager()
    
    // 공개 상태
    @Published var query: String = ""
    @Published var results: [PlaceSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldShowSearchMode = false
    @Published var hasSubmitted = false
    @Published var isResetting = false
    
    // 의존 서비스
    private let service: KakaoPlaceSearchService
    private let locationService = LocationService.shared
    private let googleService: GooglePlaceSearchService
    
    private let languageCode = Locale.current.language.languageCode?.identifier
    
    
    private init(service: KakaoPlaceSearchService? = nil, googleService: GooglePlaceSearchService? = nil) {
        self.service = service ?? KakaoPlaceSearchService()
        self.googleService = googleService ?? GooglePlaceSearchService()
    }
    
    func reset() {
        self.query = ""
        self.results = []
        self.isLoading = false
        self.errorMessage = nil
        self.shouldShowSearchMode = false
        self.hasSubmitted = false
        self.isResetting = true
           DispatchQueue.main.async { [weak self] in
               self?.isResetting = false
           }
    }
    
    func placeReset() {
        self.query = ""
        self.isLoading = false
        self.errorMessage = nil
        self.shouldShowSearchMode = false
        self.hasSubmitted = false
    }
    
    // 일반 검색
    func search() async {
        errorMessage = nil
        let kw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { results = []; return }
        
        hasSubmitted = true
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("[SearchManager] 위치 가져오기 시작...")
            
            // 캐시 우선 사용 (10분까지 허용)
            let coord = try? await locationService.getQuickCoordinate(maxAge: 600)
            
            // 1차: 키워드 검색
            let keywordResults: [KakaoPlace]
            if let coord = coord {
                print("[SearchManager] 위치 기반 키워드 검색")
                keywordResults = try await service.searchByKeyword(
                    keyword: kw,
                    x: coord.longitude,
                    y: coord.latitude,
                    size: 15
                )
            }
            else {
                print("[SearchManager] 정확도순 키워드 검색")
                keywordResults = try await service.searchByKeyword(
                    keyword: kw,
                    size: 15
                )
            }
            
            print("[SearchManager] 키워드 검색 결과: \(keywordResults.count)개")
            
            // PlaceSummary로 변환
            let summaries = keywordResults.compactMap { $0.toSummary() }
            
            // 2차: 결과 없으면 주소 검색
            if summaries.isEmpty {
                print("[SearchManager] 키워드 결과 없음 → 주소 검색 시도")
                let addressResults = try await service.searchByAddress(
                    address: kw,
                    size: 10
                )
                print("[SearchManager] 주소 검색 결과: \(addressResults.count)개")
                
                // 주소도 PlaceSummary로 변환
                results = addressResults.compactMap { $0.toSummary() }
            } else {
                results = summaries
            }
            
        } catch {
            print("[SearchManager] 검색 에러: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            results = []
        }
    }
    
    func searchInEnglish() async {
        errorMessage = nil
        let kw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { results = []; return }
        
        hasSubmitted = true
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("[SearchManager] Google Text Search 시작...")
            
            let coord = try? await locationService.getQuickCoordinate(maxAge: 600)
            
            let places: [GooglePlace]
            if let coord = coord {
                places = try await googleService.searchByText(
                    query: kw,
                    language: "en",
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    radius: 5000
                )
            } else {
                places = try await googleService.searchByText(
                    query: kw,
                    language: "en"
                )
            }
            
            print("[SearchManager] 검색 결과: \(places.count)개")
            
            results = places.compactMap { $0.toSummary() }
            
        } catch {
            print("[SearchManager] 에러: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            results = []
        }
    }
    
    // 음성검색: 전환 신호 먼저 → 검색
    func searchWithVoiceResult(_ text: String) async {
        query = text
        shouldShowSearchMode = true
        switch languageCode {
        case "en":
            await searchInEnglish()
        case "ko":
            await search()
        default:
            await searchInEnglish()
        }
        print("[SearchManager] After search - hasSubmitted: \(hasSubmitted)")
    }
    
    func resetSearchMode() {
        shouldShowSearchMode = false
    }
}
