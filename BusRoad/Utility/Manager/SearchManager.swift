import Combine
import Foundation


@MainActor
final class SearchManager: ObservableObject {
    
    static let shared = SearchManager()

    // 공개 상태
    @Published var query: String = ""
    @Published var results: [NaverLocalItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldShowSearchMode = false  // MainSearchView에서 onChange로 감시

    // 의존 서비스
    private let service: PlaceSearchService

    private init(service: PlaceSearchService = PlaceSearchService()) {
        self.service = service
    }

    // 일반 검색
    func search() async {
        errorMessage = nil
        let kw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { results = []; return }

        isLoading = true
        defer { isLoading = false }

        do {
            results = try await service.search(keyword: kw, display: 5, sort: "random")
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }

    // 음성검색: 전환 신호 먼저 → 검색
    func searchWithVoiceResult(_ text: String) async {
        query = text
        shouldShowSearchMode = true
        await search()
    }

    func resetSearchMode() { shouldShowSearchMode = false }
}
