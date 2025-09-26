import Combine
import Foundation

@MainActor
final class TextSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [NaverLocalItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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
}
