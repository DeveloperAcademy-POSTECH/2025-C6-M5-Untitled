//
//  RouteSuggestionView.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI
import CoreLocation

struct RouteSuggestionView: View {
  @StateObject private var viewModel = BusRouteViewModel()
  
  @StateObject private var locationManager = LocationManager()
  @State private var origin: LocationInfo?
  @State private var destination: LocationInfo?
  @State private var user = User(isOnBus: false)
  @State private var centerRoute: BusRoute?
  @State private var hasFetchedInitialLocation = false
  
  var body: some View {
    VStack(spacing: 10) {
      Text("경로 선택")
        .padding(.bottom,20)
      OriginTextFieldView(location: $origin,
                          onRefreshTapped: {
        print("🔄 현위치 새로고침 버튼 눌림!")
        locationManager.requestLocation()
      })
      DestinationTextFieldView(location: $destination)
      
      Divider()
        .padding(10)
      
      RouteCardSlideView(viewModel: viewModel, centerRoute: $centerRoute)
      
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
      locationManager.requestLocation()
      // 테스트를 위해 destination은 mock data로 설정
      self.destination = LocationInfo(
        name: "포항역",
        longitude: 129.3433,
        latitude: 36.0697
      )
    }
    .onChange(of: locationManager.location) { _, newLocation in
      if let location = newLocation, !hasFetchedInitialLocation {
        print("📍 새 위치 정보 수신 (최초 1회): \(location.coordinate)")
        user.currentLocation = location.coordinate
        self.origin = LocationInfo(
          name: "현위치",
          longitude: location.coordinate.longitude,
          latitude: location.coordinate.latitude
        )
        hasFetchedInitialLocation = true
      }
    }
    .onChange(of: origin) { _, newOrigin in
      viewModel.validateAndFetchRoute(origin: newOrigin, destination: destination)
    }
    .onChange(of: destination) { _, newDestination in
      viewModel.validateAndFetchRoute(origin: origin, destination: newDestination)
    }
  }
  
  var routeSelectButton: some View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    
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
