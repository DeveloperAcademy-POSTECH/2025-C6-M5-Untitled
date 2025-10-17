import CoreLocation
import SwiftUI

struct RouteSuggestionView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = BusRouteViewModel()
    @State private var user = User(isOnBus: false)
    @State var currentIndex: Int = 0
    @State var isSearchMode = false
    @State var hasSubmitted = false
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
        hasSubmitted = false
        viewModel.query = ""
        // vm.results는 매니저가 관리하니 굳이 초기화 필요 없음
    }
    
    @MainActor func performSearch() {
        isSearchMode = true
        hasSubmitted = true
        Task { await viewModel.search() }
    }
    
    @MainActor func clearSearch() {
        viewModel.query = ""
        hasSubmitted = false
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
                    if let latitude = item.latitude, let longitude = item.longitude {
                        switch locationType {
                        case .origin:
                            print(LocationInfo(name: item.plainTitle, latitude: latitude, longitude: longitude))
                            viewModel.setOrigin(origin: LocationInfo(name: item.plainTitle, latitude: latitude, longitude: longitude))
                        case .destination:
                            viewModel.setDestination(destination: LocationInfo(name: item.plainTitle, latitude: latitude, longitude: longitude))
                        }
                    }
                    // 초기화
                    viewModel.resetManager()
                    isSearchMode = false
                }
            )
        } else {
            ZStack {
                Color.primarywhite
                    
                
                VStack(spacing: 0) {
                    // MARK: - 상단바
                    VStack(spacing: 20) {
                        TopBar(isMoving: false) { coordinator.popToRoot() }
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 8) {
                            OriginTextField(
                                location: $viewModel.origin,
                                isSearchMode: $isSearchMode,
                                locationType: $locationType,
                                onRefreshTapped: { viewModel.requestOrigin() }
                            )
                            
                            DestinationTextField(
                                location: $viewModel.destination,
                                locationType: $locationType,
                                isSearchMode: $isSearchMode
                            )
                            
                        }
                        .padding(.horizontal, 22)
                        
                    LineDivider()

                    }
                    .frame(height: 194)
                    
                    ZStack {
                        Color.background
                            .ignoresSafeArea()
                        
                        // MARK: - 경로추천카드
                        VStack(spacing:0) {
                            RouteCardSlide(
                                currentIndex: $currentIndex,
                                routes: $viewModel.routes,
                                errorMessage: viewModel.errorMessage
                            )
                            .padding(.horizontal, 44.wScaled)
                            .padding(.top, 30.wScaled)
                            .padding(.bottom, 39.wScaled)
                            
                            
                            // MARK: - 버튼
                            
                            RouteSelectButton(
                                currentIndex: $currentIndex,
                                errorMessage: viewModel.errorMessage,
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
                        viewModel.requestOrigin()
                        isFirstLoad = false
                    }
                    user.currentLocation = viewModel.origin?.coordinate
                    viewModel.validateAndFetchRoute(
                        origin: viewModel.origin,
                        destination: viewModel.destination
                    )
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
    let stationA = BusStation(index: 0, stationId: 1, stationName: "포항공대 정문", stationCityCode: 37010, localStationId: "A1")
    let stationB = BusStation(index: 1, stationId: 2, stationName: "죽도시장",   stationCityCode: 37010, localStationId: "A2")

    let bus1 = BusRouteNode(
        start: LocationInfo(name: "포항공대 정문", latitude: 36.0186, longitude: 129.3231),
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
