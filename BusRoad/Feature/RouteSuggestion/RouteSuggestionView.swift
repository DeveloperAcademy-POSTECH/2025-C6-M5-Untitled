//
//  RouteSuggestionView.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteSuggestionView: View {
  @EnvironmentObject var coordinator: NavigationCoordinator
  
  @State private var user = User(isOnBus: false)
  @State private var centerRoute: BusRoute?
  
  var body: some View {
    VStack(spacing: 10) {
      Text("경로 선택")
        .padding(.bottom,20)
      DepartureTextFieldView()
      ArrivalTextFieldView()
      Divider()
        .padding(10)
      
      RouteCardSlideView(centerRoute: $centerRoute)
      
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
    }
    .padding()
  }
}

struct DepartureTextFieldView : View {
  var body: some View {
    ZStack {
      ZStack {
        RoundedRectangle(cornerSize: .init(width: 10, height: 10))
          .stroke(Color.black)
          .frame(height:50)
          .foregroundColor(.clear)
        HStack{
          Text("출발지")
            .padding(.leading, 10)
          Divider()
          Text("현위치")
          Spacer()
          Image(systemName:"arrow.clockwise")
            .padding(.trailing, 10)
        }
        .frame(height: 30)
      }
    }
  }
}

struct ArrivalTextFieldView : View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerSize: .init(width: 10, height: 10))
        .stroke(Color.black)
        .frame(height:50)
        .foregroundColor(.clear)
      HStack{
        Text("도착지")
          .padding(.leading, 10)
        Divider()
        Text("")
        Spacer()
      }
      .frame(height: 30)
    }
  }
}

#Preview {
  RouteSuggestionView()
    .environmentObject(NavigationCoordinator())
}
