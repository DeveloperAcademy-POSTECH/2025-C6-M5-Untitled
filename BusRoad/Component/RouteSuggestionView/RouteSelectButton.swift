//
//  routeSelectButton.swift
//  BusRoad
//
//  Created by 강진 on 10/12/25.
//

import SwiftUI

struct RouteSelectButton: View {
  @EnvironmentObject var coordinator: NavigationCoordinator
  @StateObject private var viewModel = BusRouteViewModel()
  @Binding var currentIndex: Int
  var errorMessage: String?
  
  var body: some View {
    if errorMessage == nil {
      Button(
          action: {
              if let routes = viewModel.routes {
                  print("[DEBUG] 버튼 클릭! 현재 index: \(currentIndex)")
                  viewModel.selectJourney(at: currentIndex)
                  coordinator.push(.walking)  // TODO: 임시 내비게이션 -> 컴포넌트에서 coordinator 쓰면 안됨. onTap으로 올려서 상위뷰에서 coordinator 쓰기
              }
          },
          label: {
              ZStack {
                  RoundedRectangle(cornerRadius: 20)
                      .frame(width: 240, height: 75)
                      .foregroundColor(Color.subStrong)
                  Text("이걸로 갈게요")
                      .foregroundColor(Color.subLight)
                      .font(.premed32)
              }
          }
      )
    } else {
      Button(
          action: {
              print(errorMessage)
              coordinator.push(.mainSearch)  // TODO: 임시 내비게이션 -> 컴포넌트에서 coordinator 쓰면 안됨. onTap으로 올려서 상위뷰에서 coordinator 쓰기
          },
          label: {
              ZStack {
                  RoundedRectangle(cornerRadius: 20)
                      .frame(width: 240, height: 75)
                      .foregroundColor(Color.subStrong)
                  Text("다시 검색하기")
                      .foregroundColor(Color.subLight)
                      .font(.premed32)
              }
          }
      )
    }
  }
}
