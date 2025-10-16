//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import CoreLocation
import SwiftUI

struct RouteSuggestionView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = BusRouteViewModel()
    @State private var user = User(isOnBus: false)
    @State var currentIndex: Int = 0
    
//     var body: some View {
//         VStack(spacing: 0){
//             TopBar(isMoving: false) { coordinator.popToRoot() }
//             Spacer()
//                 .frame(height: 20)
//             OriginTextField(
//                 location: $viewModel.origin,
//                 onRefreshTapped: { viewModel.requestOrigin() }
//             )
//             Spacer()
//                 .frame(height: 8)
//             DestinationTextField(location: $viewModel.destination)
//             Spacer()
//                 .frame(height: 22)
//             LineDivider()
            
//             ZStack {
//                 Color(.background)
//                     .ignoresSafeArea()
                
//                 VStack(spacing: 0) {
                    
//                     RouteCardSlide(
//                         currentIndex: $currentIndex,
//                         routes: viewModel.routes,
//                         errorMessage: viewModel.errorMessage
//                     )
//                     .padding(.top, 30)
//                     .padding(.bottom, 45)
                    
//                     RouteSelectButton(currentIndex: $currentIndex,
//                                       errorMessage: viewModel.errorMessage,
//                                       routes: viewModel.getJourneyList(),
    @State var isSearchMode = false
    @State var hasSubmitted = false
    @FocusState var isFocused: Bool
    @State var locationType: LocationType = .origin
    @State var isFirstLoad = true
    
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
                Rectangle()
                    .fill(Color.background)
                    .stroke(Color.greyDisable, lineWidth: 0.5)
                    .frame(maxWidth: .infinity, maxHeight: 615)    // TODO: 나중에 패딩값으로 바꾸기
                    .offset(y: UIScreen.main.bounds.height / 2 - 615 / 2 - 10)
                VStack{
                    TopBar(isMoving: false) { coordinator.popToRoot() }
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
                    
                    RouteCardSlide(
                        currentIndex: $currentIndex,
                        routes: $viewModel.routes,
                        errorMessage: viewModel.errorMessage
                    )
                    .padding([.top, .bottom], 20)
                    
                    RouteSelectButton(currentIndex: $currentIndex,
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
                    
                    if viewModel.routes == nil {
                        Text("현재 위치를 가져오는 중...")
                            .font(.caption)
                            .foregroundColor(.gray)
                             .padding(.top, 10)
                    }
                }
                .padding([.leading, .trailing, .bottom], 10)
                .onAppear {
                    print("[DEBUG] onAppear")
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
    RouteSuggestionView()
        .environmentObject(NavigationCoordinator())
}
