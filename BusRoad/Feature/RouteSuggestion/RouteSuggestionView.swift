import CoreLocation
import SwiftUI

struct RouteSuggestionView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = BusRouteViewModel()
    @State var currentIndex: Int = 0
    @State var isSearchMode = false
    @FocusState var isFocused: Bool // 이건 남겨 두셔야합니다!
    @State var locationType: LocationType = .origin
    @State var isFirstLoad = true

    var body: some View {
        if isSearchMode {
            SearchModeSection(
                query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                results: viewModel.results,
                isFocused: $isFocused,
                onBack: {
                    viewModel.exitSearchMode()
                    isSearchMode = false
                    isFocused = false
                },
                onSubmit: {
                    isSearchMode = true
                    isFocused = false
                    Task { await viewModel.performSearch() }
                },
                onClear: {
                    viewModel.clearQuery()
                    isFocused = true
                },
                onMicTap: {
                    isFocused = false
                    coordinator.push(.voiceSearch)
                },
                onSelect: { item in
                    viewModel.selectPlace(item: item, locationType: locationType)
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
                    if isFirstLoad {
                        if !viewModel.userDidSelectOrigin {
                            viewModel.requestOrigin()
                        }
                        isFirstLoad = false
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
                    if !isFirstLoad {
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
