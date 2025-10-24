import CoreLocation
import SwiftUI

struct RouteSuggestionView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = BusRouteViewModel()
    @State private var user = User(isOnBus: false)
    @State var currentIndex: Int = 0
    @State var isSearchMode = false
    @FocusState var isFocused: Bool
    @State var locationType: LocationType = .origin
    @State var isFirstLoad = true
    
    //TODO: - 프리뷰용 나중에 삭제
    private let skipAutoFetch: Bool   // 프리뷰에서 자동 네트워크/계산 생략용
    init(viewModel: BusRouteViewModel = BusRouteViewModel(), skipAutoFetch: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.skipAutoFetch = skipAutoFetch
    }
    
    // MARK: - Helpers
    @MainActor func exitSearchMode() {
        isSearchMode = false
        isFocused = false
        viewModel.query = ""
        // vm.results는 매니저가 관리하니 굳이 초기화 필요 없음
    }
    
    @MainActor func performSearch() {
        isSearchMode = true
        Task { await viewModel.search() }
    }
    
    @MainActor func clearSearch() {
        viewModel.query = ""
        isFocused = true
    }
    
    var body: some View {
        if isSearchMode {
            SearchModeSection(
                query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                results: viewModel.results,
                isFocused: $isFocused,
                onBack: { exitSearchMode() },
                onSubmit: { performSearch() },
                onClear: { clearSearch() },
                onMicTap: {
                    isFocused = false
                    coordinator.push(.voiceSearch)
                },
                onSelect: { item in
                    
                    switch locationType {
                    case .origin:
                        print(LocationInfo(name: item.name, latitude: item.latitude, longitude: item.longitude))
                        viewModel.setOrigin(origin: LocationInfo(
                            name: item.name,
                            latitude: item.latitude,    // 바로 사용!
                            longitude: item.longitude   // 바로 사용!
                        ))
                    case .destination:
                        viewModel.setDestination(destination: LocationInfo(
                            name: item.name,
                            latitude: item.latitude,
                            longitude: item.longitude
                        ))
                    }
                    // 초기화
                    viewModel.resetManager()
                    isSearchMode = false
                },
                hasSubmitted: $viewModel.hasSubmitted,
                isLoading: viewModel.isSearchLoading
            )
        } else {
            ZStack {
                Color.primarywhite
                    .ignoresSafeArea()
                
                
                VStack(spacing: 0) {
                    // MARK: - 상단바
                    VStack(spacing: 0) {
                        TopBar(isMoving: false) { coordinator.popToRoot() }
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 8) {
                            OriginTextField(
                                location: $viewModel.origin,
                                isSearchMode: $isSearchMode,
                                locationType: $locationType,
                                userDidSelectOrigin: $viewModel.userDidSelectOrigin,
                                onRefreshTapped: {
                                    viewModel.userDidSelectOrigin = false
                                    viewModel.requestOrigin() }
                            )
                            
                            DestinationTextField(
                                location: $viewModel.destination,
                                locationType: $locationType,
                                isSearchMode: $isSearchMode
                            )
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 22)
                    }
                    .frame(height: 194)
                    
                    LineDivider()
                    
                    ZStack {
                        Color.background
                            .ignoresSafeArea()
                        
                        // MARK: - 경로추천카드
                        VStack(spacing:0) {
                            RouteCardSlide(
                                currentIndex: $currentIndex,
                                routes: $viewModel.routes,
                                viewModel: viewModel,
                                errorMessage: viewModel.errorMessage
                            )
                            .padding(.horizontal, 44.wScaled)
                            .padding(.top, 30.wScaled)
                            .padding(.bottom, 17.wScaled)
                            
                            
                            // MARK: - 버튼
                            
                            RouteSelectButton(
                                viewModel: viewModel,
                                currentIndex: $currentIndex,
                                routes: viewModel.routes,
                                onSelect: {
                                    viewModel.selectJourney(at: currentIndex)
                                    coordinator.push(.journeyFlow)
                                },
                                retrySearch: {
                                    print(viewModel.errorMessage)
                                    coordinator.popToRoot() // MainSearch로 초기화
                                }
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 74)
                        }
                    }
                }
                .onAppear {
                    print("[DEBUG] onAppear")
                    guard !skipAutoFetch else { return }
                    if isFirstLoad {
                        if !viewModel.userDidSelectOrigin {
                            viewModel.requestOrigin()
                        }
                        isFirstLoad = false
                    }
                    user.currentLocation = viewModel.origin?.coordinate
                    viewModel.validateAndFetchRoute(
                        origin: viewModel.origin,
                        destination: viewModel.destination
                    )
                }
                .task {
                    NotificationCenter.default.addObserver(
                        forName: .didSetPresetDestination,
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let destinationName = notification.object as? String {
                            viewModel.query = destinationName
                            isSearchMode = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isFocused = true
                            }
                            Task {
                                await viewModel.search()
                            }
                        }
                    }
                }
                .onChange(of: viewModel.origin) { _, newOrigin in
                    if !isFirstLoad {
                        user.currentLocation = viewModel.origin?.coordinate
                        print("[DEBUG] origin updated")
                        viewModel.validateAndFetchRoute(
                            origin: newOrigin,
                            destination: viewModel.destination
                        )
                    }
                }
                .onChange(of: viewModel.destination) { _, newDestination in
                    if !isFirstLoad {
                        print("[DEBUG] destination updated")
                        viewModel.validateAndFetchRoute(
                            origin: viewModel.origin,
                            destination: newDestination
                        )
                    }
                }
                .onChange(of: viewModel.routes) { _, _ in
                    print("[DEBUG] routes updated")
                    currentIndex = 0
                }
            }
        }
    }
}


#Preview {
    let coordinator = NavigationCoordinator()
    let vm = BusRouteViewModel()
    
    // 더미 데이터
    let stationA = BusStation(index: 0, stationId: 1, stationName: "효자동 행정복지센터ㅇㅇㅇㅇㅇ", stationCityCode: 37010, localStationId: "A1")
    let stationB = BusStation(index: 1, stationId: 2, stationName: "죽도시장",   stationCityCode: 37010, localStationId: "A2")
    
    let bus1 = BusRouteNode(
        start: LocationInfo(name: "효자동 행정복지센터ㅇㅇㅇㅇㅇ", latitude: 36.0186, longitude: 129.3231),
        end:   LocationInfo(name: "죽도시장",   latitude: 36.0348, longitude: 129.3435),
        busNo: "107", busId: 107, stations: [stationA, stationB], travelTime: 15
    )
    let bus2 = bus1
    let bus3 = bus1
    
    vm.routes = [
        Journey(totalTime: 15, nodes: [.bus(bus1)]),
        Journey(totalTime: 20, nodes: [.bus(bus2)]),
        Journey(totalTime: 30, nodes: [.bus(bus3)])
    ]
    vm.origin = LocationInfo(name: "포항공대 정문", latitude: 36.0186, longitude: 129.3231)
    vm.destination = LocationInfo(name: "죽도시장",   latitude: 36.0348, longitude: 129.3435)
    
    return RouteSuggestionView(viewModel: vm, skipAutoFetch: true)
        .environmentObject(coordinator)
}
