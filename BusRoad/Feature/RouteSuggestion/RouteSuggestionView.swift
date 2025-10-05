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

    //  @StateObject private var locationManager = LocationManager()
    //  @State private var origin: LocationInfo?
    //  @State private var destination: LocationInfo?
    @State private var user = User(isOnBus: false)
    //  @State private var centerRoute: BusRoute?
    //  @State private var hasFetchedInitialLocation = false
    @State var currentIndex = 0

    var body: some View {
        VStack(spacing: 10) {
            Text("경로 선택")
                .padding(.bottom, 20)
            OriginTextField(
                location: $viewModel.origin,
                onRefreshTapped: { viewModel.requestOrigin() }
            )
            DestinationTextField(location: $viewModel.destination)

            Divider()
                .padding(10)

            RouteCardSlide(
                currentIndex: $currentIndex,
                routes: viewModel.routes,
                errorMessage: viewModel.errorMessage
            )

            routeSelectButton

            if viewModel.routes == nil {
                Text("현재 위치를 가져오는 중...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .onAppear {
            viewModel.requestOrigin()
            user.currentLocation = viewModel.origin?.coordinate
        }
        //    .onChange(of: locationManager.location) { _, newLocation in
        //      if let location = newLocation, !hasFetchedInitialLocation {
        //        print("📍 새 위치 정보 수신 (최초 1회): \(location.coordinate)")
        //        user.currentLocation = location.coordinate
        //        self.origin = LocationInfo(
        //          name: "현위치",
        //          longitude: location.coordinate.longitude,
        //          latitude: location.coordinate.latitude
        //        )
        //        hasFetchedInitialLocation = true
        //      }
        //    }
        .onChange(of: viewModel.origin) { _, newOrigin in
            print("[DEBUG] origin updated")
            viewModel.validateAndFetchRoute(
                origin: newOrigin,
                destination: viewModel.destination
            )
        }
        .onChange(of: viewModel.destination) { _, newDestination in
            print("[DEBUG] destination updated")
            viewModel.validateAndFetchRoute(
                origin: viewModel.origin,
                destination: newDestination
            )
        }
        .onChange(of: viewModel.routes) { _, _ in
            print("[DEBUG] routes updated")
            currentIndex = 0
        }
    }

    var routeSelectButton: some View {

        return Button(
            action: {
                //      if let route = centerRoute {
                //        user.selectedRoute = route
                //        print("✅ 선택된 경로: \(route.busNumbers.joined(separator: ", "))번 버스...")
                //        coordinator.push(.mainSearch)
                //      }
                if let routes = viewModel.routes {
                    print("[DEBUG] 버튼 클릭! 현재 index: \(currentIndex)")
                    viewModel.selectJourney(at: currentIndex)
                    coordinator.push(.mainSearch)  // TODO: 임시 내비게이션
                }
            },
            label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .frame(width: 230, height: 65)
                        .foregroundColor(.black)
                    Text("이걸로 갈게요")
                        .foregroundColor(Color.white)
                        .font(.title)
                }
            }
        )
    }
}

#Preview {
    RouteSuggestionView()
        .environmentObject(NavigationCoordinator())
}
