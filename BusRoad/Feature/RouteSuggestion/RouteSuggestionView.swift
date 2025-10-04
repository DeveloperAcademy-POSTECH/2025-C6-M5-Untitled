//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI
import CoreLocation

struct RouteSuggestionView: View {
  @EnvironmentObject var coordinator: NavigationCoordinator
  @StateObject private var viewModel = BusRouteViewModel()
  
//  @StateObject private var locationManager = LocationManager()  // TODO: View에서는 Manager 참조하지 않도록 수정하기(ViewModel에서만)
//  @State private var origin: LocationInfo?
//  @State private var destination: LocationInfo?
  @State private var user = User(isOnBus: false)
  @State private var centerRoute: BusRoute?
  @State private var hasFetchedInitialLocation = false
  
  var body: some View {
    VStack(spacing: 10) {
      Text("경로 선택")
        .padding(.bottom, 20)
        OriginTextField(location: $viewModel.origin,
                      onRefreshTapped: { viewModel.requestOrigin() }
      )
        DestinationTextField(location: $viewModel.destination)
      
      Divider()
        .padding(10)
      
      RouteCardSlide(viewModel: viewModel, centerRoute: $centerRoute)
      
      routeSelectButton
      
      if let location = user.currentLocation {
      } else {
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
        viewModel.validateAndFetchRoute(origin: newOrigin, destination: viewModel.destination)
    }
    .onChange(of: viewModel.destination) { _, newDestination in
        viewModel.validateAndFetchRoute(origin: viewModel.origin, destination: newDestination)
    }
  }
  
  var routeSelectButton: some View {
    
    return Button(action: {
      print("🅿️ 버튼 클릭! 현재 centerRoute: \(centerRoute?.busNumbers.first ?? "nil")")
      if let route = centerRoute {
        user.selectedRoute = route
        print("✅ 선택된 경로: \(route.busNumbers.joined(separator: ", "))번 버스...")
        coordinator.push(.mainSearch)
      }
    }, label: {
      ZStack{
        RoundedRectangle(cornerRadius:25)
          .frame(width: 230, height: 65)
          .foregroundColor(.black)
        Text("이걸로 갈게요")
          .foregroundColor(Color.white)
          .font(.title)
      }
    })
  }
}

#Preview {
  RouteSuggestionView()
    .environmentObject(NavigationCoordinator())
}
