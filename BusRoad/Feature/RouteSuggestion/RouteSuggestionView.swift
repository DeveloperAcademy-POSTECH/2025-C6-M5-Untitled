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
  @EnvironmentObject var coordinator: NavigationCoordinator
  
  @StateObject private var locationManager = LocationManager()
  @State private var origin: LocationInfo?
  @State private var destination: LocationInfo?
  @State private var user = User(isOnBus: false)
  @State private var centerRoute: BusRoute?
  
  var body: some View {
    VStack(spacing: 10) {
      Text("경로 선택")
        .padding(.bottom,20)
      OriginTextFieldView(location: $origin)
      DestinationTextFieldView(location: $destination)
      
      Divider()
        .padding(10)
      
      RouteCardSlideView(viewModel: viewModel, centerRoute: $centerRoute)
      
      Button(action: {
        if let route = centerRoute {
          user.selectedRoute = route
          print("✅ 선택된 경로: \(route.busNumbers.joined(separator: ", "))번 버스, 소요시간 \(route.totalTime)분")
          coordinator.push(.onRide)
          //네비게이션이랑 로그 다른 파일에선 되다가 갑자기 안 돼서 2시간 째 붙잡고 있었는데 여전히 안 되네요,,, 주말에 수정해보겠습니다
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
      if let location = newLocation {
        print("📍 새 위치 정보 수신: \(location.coordinate)")
        user.currentLocation = location.coordinate
        self.origin = LocationInfo(
          name: "현위치",
          longitude: location.coordinate.longitude,
          latitude: location.coordinate.latitude
        )
      }
    }
    .onChange(of: origin) { _, newOrigin in
      viewModel.validateAndFetchRoute(origin: newOrigin, destination: destination)
    }
    .onChange(of: destination) { _, newDestination in
      viewModel.validateAndFetchRoute(origin: origin, destination: newDestination)
    }
  }
}

#Preview {
  RouteSuggestionView()
    .environmentObject(NavigationCoordinator())
}
