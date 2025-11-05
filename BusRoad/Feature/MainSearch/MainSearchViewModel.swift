import Combine
import Foundation
import MapKit

@MainActor
final class MainSearchViewModel: ObservableObject {
    @Published var hasSubmitted: Bool = false
    @Published var isSearchMode: Bool = false
    @Published var showHint: Bool = false
    @Published var hasShownVoiceHint: Bool {
        didSet {
            UserDefaults.standard.set(hasShownVoiceHint, forKey: kHasShownVoiceHint)
        }
    }
    
    private let kHasShownVoiceHint = "hasShownVoiceHint_v1"
    private var bag = Set<AnyCancellable>()
    
    let searchManager = SearchManager.shared
    let journeyManager = JourneyManager.shared
    
    var query: String {
        get { searchManager.query }
        set { searchManager.query = newValue }
    }
    var results: [PlaceSummary] { searchManager.results }
    var shouldShowSearchMode: Bool { searchManager.shouldShowSearchMode }
    var isLoading: Bool { searchManager.isLoading }
    var errorMessage: String? { searchManager.errorMessage }
    
    
    init() {
        self.hasShownVoiceHint = UserDefaults.standard.bool(forKey: kHasShownVoiceHint)
        searchManager.$hasSubmitted
            .assign(to: &$hasSubmitted)
        
        searchManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }
    
    func search() async { await searchManager.search() }
    func resetSearchMode() { searchManager.resetSearchMode() }
    
    func setDestination(destination: LocationInfo) {
        journeyManager.setDestination(destination)
    }
    
    func resetManager() {
        searchManager.reset()
    }
    
    // MARK: - 액션 메서드들
    /// 검색 모드 종료
    func exitSearchMode() {
        query = ""
        resetManager()
        isSearchMode = false
    }
    
    /// 검색 수행
    func performSearch() async {
        showHint = false
        isSearchMode = true
        await search()
    }
    
    /// 검색어 초기화
    func clearQuery() {
        showHint = false
        query = ""
    }
    
    /// 마이크 버튼 탭
    func handleMicTap() {
        showHint = false
    }
    
    /// 장소 선택
    func selectPlace(item: PlaceSummary) {
        setDestination(destination: LocationInfo(
            name: item.name,
            latitude: item.latitude,
            longitude: item.longitude
        ))
        resetManager()
        isSearchMode = false
    }
    
    func warmUpLocation() {
        journeyManager.warmUpLocation()
    }
}
