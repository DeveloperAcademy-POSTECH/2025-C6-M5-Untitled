//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct BeforeRideView: View {
  @StateObject private var viewmodel = BeforeRideViewModel()
  
  var body: some View {
    ZStack {
      Color(.background)
        .ignoresSafeArea()
      
      VStack(spacing: 47) {
        
        //Todo: 전체 경로 들어가야 함
        
        BeforeRideCard(
          waitingStopName: viewmodel.waitingStopName,
          waitingBusNO: viewmodel.waitingBusNO,
          remainingStopsToBoarding: $viewmodel.remainingStops,
          remainingTimeToBoarding: viewmodel.remainingTime
        )
        .padding(.horizontal, 24)
        
        
        if viewmodel.remainingStops == 1 {
          Button {
            // TODO: 다음화면으로 넘어가도록하는 액션
          } label: {
            Text("탔어요")
              .font(.premed32)
              .foregroundStyle(.subLight)
              .frame(width: 239, height: 74)
              .background(.subStrong)
              .cornerRadius(20)
          }
          .buttonStyle(.plain)
        } else {
          Button {
            // TODO: 비활성화 상태에서의 동작(토스트/알럿/햅틱 등)
            // “1정류장 남으면 버튼이 활성화돼요”
          } label: {
            Text("탔어요")
              .font(.premed32)
              .foregroundStyle(.subNeutral)
              .frame(width: 239, height: 74)
              .background(.subDisable)
              .cornerRadius(20)
          }
        }
      }
    }
  }
}
