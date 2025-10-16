import Combine
import Foundation
import MapKit

@MainActor
final class MainSearchViewModel: ObservableObject {
    
    let searchManager = SearchManager.shared
    let journeyManager = JourneyManager.shared

    // SearchManager의 변경을 View로 릴레이 (UI 갱신 보장)
    private var bag = Set<AnyCancellable>()
    init() {
        searchManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }

    // 뷰에서 쓰기 편한 프록시
    var query: String {
        get { searchManager.query }
        set { searchManager.query = newValue }
    }
    var results: [NaverLocalItem] { searchManager.results }
    var shouldShowSearchMode: Bool { searchManager.shouldShowSearchMode }
    var isLoading: Bool { searchManager.isLoading }
    var errorMessage: String? { searchManager.errorMessage }

  
    func search() async { await searchManager.search() }
    func resetSearchMode() { searchManager.resetSearchMode() }
    
    func setDestination(destination: LocationInfo) {
        journeyManager.setDestination(destination)
    }
    
    func resetManager() {
        searchManager.reset()
    }
    
    func requestOrigin() {
        journeyManager.requestOrigin()
    }
    
}
