//
//  VerifyingStop.swift
//  BusRoad
//
//  Created by 강진 on 10/14/25.
//

import SwiftUI

struct VerifyingStop: View {
  @EnvironmentObject var coordinator: NavigationCoordinator
  @Binding var showVerifyingStop: Bool
  
  var journey: Journey
  var index: Int
  
  var body: some View {
    Spacer()
    
    if case let .walk(node) = journey.nodes[index] {
      VStack(alignment: .leading) {
        Spacer()
        
        Text(node.end.name)
          .font(.presemi36)
          .foregroundColor(.primaryHeavy)
          .padding(.bottom, 20)
        
        
        Text("정류장 이름이 맞는지\n확인해주세요.")
          .font(.prereg32)
          .foregroundStyle(Color.primaryHeavy)
        
        Spacer()
        
        HStack{
          Spacer()
          Button {
            coordinator.advanceJourneyStage()
            showVerifyingStop = false
          } label: {
            ZStack{
              Rectangle()
                .cornerRadius(20)
                .foregroundColor(.subStrong)
                .frame(width: 240, height: 75)
              Text("맞아요")
                .font(.premed32)
                .foregroundColor(.subLight)
            }
          }
          Spacer()
        }
        .padding(.bottom,50)
      }
      .padding(.horizontal, 30)
      
    } else {
      Text("경로 정보 확인 불가")
        .font(.presemi36)
        .foregroundColor(.red)
    }
  }
}
