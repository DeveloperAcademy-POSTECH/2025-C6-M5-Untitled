import Combine
import Foundation

@MainActor
final class TextSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [NaverLocalItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldShowSearchMode = false // 음성 검색 완료 후 검색 모드 표시용
    @Published var isFromVoiceSearch = false

    private let manager: PlaceSearchManager

    init(manager: PlaceSearchManager = PlaceSearchManager()) {
        self.manager = manager
    }

    /// 엔터/버튼에서 호출
    func search() async {
        errorMessage = nil
        let kw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { results = []; return }

        isLoading = true
        defer { isLoading = false }

        do {
            results = try await manager.search(keyword: kw, display: 5, sort: "random")
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }
    
    /// 음성 검색 완료 처리 (검색어 설정 + 검색 실행 + 모드 전환)
    func searchWithVoiceResult(_ text: String) async {
        query = text
        await search()
        isFromVoiceSearch = true
        shouldShowSearchMode = true
    }
    
    /// 검색 모드 상태 초기화
    func resetSearchMode() {
        shouldShowSearchMode = false
        isFromVoiceSearch = false
    }
}
