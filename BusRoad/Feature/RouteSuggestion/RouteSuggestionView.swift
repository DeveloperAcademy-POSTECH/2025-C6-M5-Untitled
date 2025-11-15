import CoreLocation
import SwiftUI

struct RouteSuggestionView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = BusRouteViewModel()
    @FocusState var isFocused: Bool
    
    var body: some View {
        if viewModel.isSearchMode {
            SearchModeSection(
                query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                results: viewModel.results,
                isFocused: $isFocused,
                onBack: {
                    viewModel.exitSearchMode()
                    viewModel.isSearchMode = false
                    isFocused = false
                },
                onSubmit: {
                    viewModel.isSearchMode = true
                    isFocused = false
                    Task { await viewModel.performSearch() }
                },
                onClear: {
                    viewModel.clearQuery()
                    isFocused = true
                },
                onMicTap: {
                    isFocused = false
                    viewModel.handleMicTap()
                },
                onSelect: { item in
                    viewModel.selectPlace(item: item, locationType: viewModel.locationType)
                    viewModel.isSearchMode = false
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
                    VStack(spacing: 8) {
                        RouteTopBar()
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 8) {
                            OriginTextField(
                                location: $viewModel.origin,
                                isSearchMode: $viewModel.isSearchMode,
                                locationType: $viewModel.locationType,
                                userDidSelectOrigin: $viewModel.userDidSelectOrigin,
                                isRefreshingLocation: $viewModel.isRefreshingLocation,
                                onRefreshTapped: {
                                    await viewModel.forceRefreshOrigin()
                                }
                            )
                            
                            DestinationTextField(
                                location: $viewModel.destination,
                                locationType: $viewModel.locationType,
                                isSearchMode: $viewModel.isSearchMode
                            )
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                    .frame(height: 166)
                    
                    LineDivider()
                    
                    ZStack {
                        Color.background
                            .ignoresSafeArea()
                        
                        // MARK: - 경로추천카드
                        VStack(spacing:0) {
                            
                            RouteCardSlide(
                                currentIndex: $viewModel.currentIndex,
                                routes: $viewModel.routes,
                                viewModel: viewModel
                            )
                            .padding(.horizontal, 44.wScaled)
                            .padding(.top, 30.wScaled)
                            .padding(.bottom, 17.wScaled)
                            
                            // MARK: - 버튼
                            
                            if viewModel.isLoading {
                                Rectangle()
                                    .fill(.subDisable)
                                    .frame(width: 305.wScaled, height: 64)
                                    .cornerRadius(20)
                                
                            } else {
                                RouteSelectButton(
                                    viewModel: viewModel,
                                    currentIndex: $viewModel.currentIndex,
                                    routes: viewModel.routes,
                                    onSelect: {
                                        viewModel.selectJourney(at: viewModel.currentIndex)
                                        coordinator.push(.journeyFlow)
                                    },
                                    retrySearch: {
                                        print(viewModel.errorMessage ?? "Unknown error")
                                        coordinator.popToRoot() // MainSearch로 초기화
                                    }
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                            }
                        }
                    }
                }
                .onAppear {
                    print("[DEBUG] onAppear")
                    if viewModel.isFirstLoad {
                        viewModel.fetchFirstLoadedLocation()    // warm-up때 가져왔던 현위치 그대로 사용(단 한번만)
                        if !viewModel.userDidSelectOrigin {
                            viewModel.requestOrigin()
                        }
                        viewModel.isFirstLoad = false
                    }
                    viewModel.validateAndFetchRoute(
                        origin: viewModel.origin,
                        destination: viewModel.destination
                    )
                }
                //                .task {
                //                    NotificationCenter.default.addObserver(
                //                        forName: .didSetPresetDestination,
                //                        object: nil,
                //                        queue: .main
                //                    ) { notification in
                //                        if let destinationName = notification.object as? String {
                //                            viewModel.query = destinationName
                //                            isSearchMode = true
                //                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                //                                isFocused = true
                //                            }
                //                            Task {
                //                                await viewModel.search()
                //                            }
                //                        }
                //                    }
                //                }
                .onChange(of: viewModel.origin) { _, newOrigin in
                    if !viewModel.isFirstLoad {
                        print("[DEBUG] origin updated")
                        viewModel.validateAndFetchRoute(
                            origin: newOrigin,
                            destination: viewModel.destination
                        )
                    }
                }
                .onChange(of: viewModel.destination) { _, newDestination in
                    if !viewModel.isFirstLoad {
                        print("[DEBUG] destination updated")
                        viewModel.validateAndFetchRoute(
                            origin: viewModel.origin,
                            destination: newDestination
                        )
                    }
                }
                .onChange(of: viewModel.routes) { _, _ in
                    print("[DEBUG] routes updated")
                    viewModel.currentIndex = 0
                }
            }
        }
    }
}


#if DEBUG
import SwiftUI

struct RouteSuggestionView_Previews: PreviewProvider {
    static var previews: some View {
        RouteSuggestionView()
            .environmentObject(NavigationCoordinator())
            .previewDisplayName("기본 상태")
        
        RouteSuggestionViewWithData()
            .environmentObject(NavigationCoordinator())
            .previewDisplayName("경로 데이터 있음")
    }
}

struct RouteSuggestionViewWithData: View {
    @StateObject private var viewModel: BusRouteViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator
    @FocusState var isFocused: Bool
    
    init() {
        let vm = BusRouteViewModel()
        
        // 목 데이터 설정
        vm.origin = LocationInfo(
            name: "서울역",
            latitude: 37.5547125,
            longitude: 126.9707878
        )
        vm.destination = LocationInfo(
            name: "강남역",
            latitude: 37.4979502,
            longitude: 127.0276368
        )
        
        // 공통 스테이션 목 데이터 헬퍼
        func makeStations(start: LocationInfo, end: LocationInfo) -> [BusStation] {
            return [
                BusStation(
                    index: 0,
                    stationId: 1000,
                    stationName: "\(start.name) 정류장",
                    stationCityCode: 11,
                    localStationId: "L\(1000)",
                    nodeId: "A\(1000)",
                    latitude: start.latitude,
                    longitude: start.longitude
                ),
                BusStation(
                    index: 1,
                    stationId: 1001,
                    stationName: "\(end.name) 정류장",
                    stationCityCode: 11,
                    localStationId: "L\(1001)",
                    nodeId: "A\(1001)",
                    latitude: end.latitude,
                    longitude: end.longitude
                )
            ]
        }
        
        vm.routes = [
            Journey(totalTime: 48, nodes: [
                .walk(WalkRouteNode(
                    start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "서울역 정류장", latitude: 37.55, longitude: 126.97),
                    travelTime: 5
                )),
                .bus(BusRouteNode(
                    start: LocationInfo(name: "서울역 정류장", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "강남역 정류장", latitude: 37.49, longitude: 127.02),
                    busNo: ["405", "472"],
                    busId: [4050, 4720],
                    stations: makeStations(
                        start: LocationInfo(name: "서울역 정류장", latitude: 37.55, longitude: 126.97),
                        end: LocationInfo(name: "강남역 정류장", latitude: 37.49, longitude: 127.02)
                    ),
                    travelTime: 35
                )),
                .walk(WalkRouteNode(
                    start: LocationInfo(name: "강남역 정류장", latitude: 37.49, longitude: 127.02),
                    end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02),
                    travelTime: 3
                ))
            ]),
            Journey(totalTime: 52, nodes: [
                .walk(WalkRouteNode(
                    start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "서울역 정류장", latitude: 37.55, longitude: 126.97),
                    travelTime: 10
                )),
                .bus(BusRouteNode(
                    start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02),
                    busNo: ["401"],
                    busId: [4010],
                    stations: makeStations(
                        start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                        end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02)
                    ),
                    travelTime: 42
                ))
            ]),
            Journey(totalTime: 60, nodes: [
                .walk(WalkRouteNode(
                    start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "서울역 정류장", latitude: 37.55, longitude: 126.97),
                    travelTime: 2
                )),
                .bus(BusRouteNode(
                    start: LocationInfo(name: "서울역 정류장", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "역삼역 정류장", latitude: 37.50, longitude: 127.03),
                    busNo: ["146"],
                    busId: [1460],
                    stations: makeStations(
                        start: LocationInfo(name: "서울역 정류장", latitude: 37.55, longitude: 126.97),
                        end: LocationInfo(name: "역삼역 정류장", latitude: 37.50, longitude: 127.03)
                    ),
                    travelTime: 25
                )),
                .walk(WalkRouteNode(
                    start: LocationInfo(name: "역삼역 정류장", latitude: 37.50, longitude: 127.03),
                    end: LocationInfo(name: "역삼역 환승", latitude: 37.50, longitude: 127.03),
                    travelTime: 1
                )),
                .bus(BusRouteNode(
                    start: LocationInfo(name: "역삼역 환승", latitude: 37.50, longitude: 127.03),
                    end: LocationInfo(name: "강남역 정류장", latitude: 37.49, longitude: 127.02),
                    busNo: ["341"],
                    busId: [3410],
                    stations: makeStations(
                        start: LocationInfo(name: "역삼역 환승", latitude: 37.50, longitude: 127.03),
                        end: LocationInfo(name: "강남역 정류장", latitude: 37.49, longitude: 127.02)
                    ),
                    travelTime: 15
                )),
                .walk(WalkRouteNode(
                    start: LocationInfo(name: "강남역 정류장", latitude: 37.49, longitude: 127.02),
                    end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02),
                    travelTime: 2
                ))
            ])
        ]
        vm.isFirstLoad = false
        
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
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
                            isSearchMode: $viewModel.isSearchMode,
                            locationType: $viewModel.locationType,
                            userDidSelectOrigin: $viewModel.userDidSelectOrigin,
                            isRefreshingLocation: $viewModel.isRefreshingLocation,
                            onRefreshTapped: {
                                viewModel.userDidSelectOrigin = false
                                viewModel.requestOrigin()
                            }
                        )
                        
                        DestinationTextField(
                            location: $viewModel.destination,
                            locationType: $viewModel.locationType,
                            isSearchMode: $viewModel.isSearchMode
                        )
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .frame(height: 166)
                
                LineDivider()
                
                ZStack {
                    Color.background
                        .ignoresSafeArea()
                    
                    // MARK: - 경로추천카드
                    VStack(spacing:0) {
                        RouteCardSlide(
                            currentIndex: $viewModel.currentIndex,
                            routes: $viewModel.routes,
                            viewModel: viewModel
                        )
                        .padding(.horizontal, 44.wScaled)
                        .padding(.top, 25.wScaled)
                        .padding(.bottom, 29.wScaled)
                        
                        // MARK: - 버튼
                        RouteSelectButton(
                            viewModel: viewModel,
                            currentIndex: $viewModel.currentIndex,
                            routes: viewModel.routes,
                            onSelect: {
                                viewModel.selectJourney(at: viewModel.currentIndex)
                                coordinator.push(.journeyFlow)
                            },
                            retrySearch: {
                                print(viewModel.errorMessage ?? "Unknown error")
                                coordinator.popToRoot()
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                    }
                }
            }
        }
    }
}
#endif
