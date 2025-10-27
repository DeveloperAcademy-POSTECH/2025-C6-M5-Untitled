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
    
    // 의존 서비스
    private let service: KakaoPlaceSearchService
    private let locationService = LocationService()
    
    
    private init(service: KakaoPlaceSearchService? = nil) {
        self.service = service ?? KakaoPlaceSearchService()
    }
    
    func reset() {
        self.query = ""
        self.results = []
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
            let coord = try? await locationService.requestOneShotCoordinate(timeout: 5)
            
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
    
    
    // 음성검색: 전환 신호 먼저 → 검색
    func searchWithVoiceResult(_ text: String) async {
        query = text
        shouldShowSearchMode = true
        await search()
        print("[SearchManager] After search - hasSubmitted: \(hasSubmitted)")
    }
    
    func resetSearchMode() {
        shouldShowSearchMode = false
    }
}
