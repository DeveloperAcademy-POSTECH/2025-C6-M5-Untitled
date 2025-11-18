import Combine
import Foundation
import MapKit

@MainActor
final class MainSearchViewModel: ObservableObject {
    @Published var hasSubmitted: Bool = false
    @Published var isSearchMode: Bool = false
    @Published var showHint: Bool = false
    @Published var isReturningFromRoute: Bool = false
    @Published var showDestinationMap: Bool = false
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
        
        searchManager.$isResetting
            .filter { $0 }  // true일 때만
            .sink { [weak self] _ in
                guard let self = self else { return }
                // popToRoot로 돌아온 경우가 아닐 때만 false로 설정
                if !self.isReturningFromRoute {
                    self.isSearchMode = false
                }
            }
            .store(in: &bag)
    }
    
    func search() async {
        await searchManager.search()
    }
    
    func resetSearchMode() {
        searchManager.resetSearchMode()
    }
    
    func setDestination(destination: LocationInfo) {
        journeyManager.setDestination(destination)
    }
    
    func resetManager() {
        searchManager.reset()
    }
    
    func warmUpLocation() {
        journeyManager.warmUpLocation()
    }
    
    // MARK: - 액션 메서드들
    /// 검색 모드 종료
    func exitSearchMode() {
        isSearchMode = false
        query = ""
        resetManager()
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
    
    /// 마이크 버튼 탭 → 풀스크린 뷰 열기
    func handleMicTap() {
        showHint = false
        VoiceSearchManager.shared.present { [weak self] text in
            self?.handleVoiceSearchCompleted(text)
        }
    }
    
    /// 음성 검색 완료 → 쿼리 반영 + 검색 실행
    func handleVoiceSearchCompleted(_ text: String) {
        showHint = false
        query = text
        isSearchMode = true
        
        Task { [weak self] in
            await self?.search()
        }
    }
    
    /// 음성 검색 뷰에서 닫기
    func dismissVoiceSearch() {
        VoiceSearchManager.shared.dismiss()
    }
    
    /// 장소 선택
    func selectPlace(item: PlaceSummary) {
        setDestination(destination: LocationInfo(
            name: item.name,
            latitude: item.latitude,
            longitude: item.longitude
        ))
        
        searchManager.placeReset()
    }
}
