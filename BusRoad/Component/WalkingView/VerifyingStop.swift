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
            .font(.presemi36Scaled)
            .foregroundColor(.primaryHeavy)
            .padding(.bottom, 20)
          
          
          Text("정류장 이름이 맞는지\n확인해주세요.")
            .font(.prereg32Scaled)
            .foregroundStyle(Color.primaryHeavy)
          
          Spacer()
          
          HStack{
            Spacer()
            Button {
              coordinator.advanceJourneyStage()
              showVerifyingStop = false
            } label: {
              Text("맞아요")
                .font(.premed32Scaled)
                .foregroundColor(.subLight)
                .background(
                  Rectangle()
                    .cornerRadius(20)
                    .foregroundColor(.subStrong)
                    .frame(width: 240, height: 75)
                )
            }
            Spacer()
          }
          .padding(.bottom, 50.wScaled)
        }
        .padding(.horizontal, 30.wScaled)
        
      } else {
        Text("경로 정보 확인 불가")
          .font(.presemi36Scaled)
          .foregroundColor(.red)
      }
    }
}
