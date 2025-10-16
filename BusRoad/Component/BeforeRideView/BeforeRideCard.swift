//
//  Card.swift
//  C6test
//
//  Created by 강진 on 10/1/25.
//

import SwiftUI


struct BeforeRideCard: View {
  
  let waitingStopName: String
  let waitingBusNO: String
  @Binding var remainingStopsToBoarding: Int
  let remainingTimeToBoarding: Int
  
  
  var body: some View {
      
      ZStack {
          Rectangle()
              .foregroundColor(remainingStopsToBoarding == 1 ? .primaryNormal : .subNormal)
              .cornerRadius(20)
          
          VStack(spacing: 20) {
              
              VStack(spacing: 28) {
                  HStack {
                      VStack(alignment: .leading, spacing: 8) {
                          Text(waitingStopName)
                              .font(.prebold36)
                              .foregroundStyle(remainingStopsToBoarding == 1 ? .subLight : .primaryHeavy)
                          
                          Text("정류장에서 타야 해요.")
                              .font(.prereg24)
                              .foregroundStyle(remainingStopsToBoarding == 1 ? .subLight : .primaryHeavy)
                      }
                      Spacer()
                  }
                  .border(.yellow)
                  
                  HStack{
                      Text("\(waitingBusNO)")
                          .font(.presemi32)
                          .foregroundStyle(
                            remainingStopsToBoarding == 1 ? .primaryNormal: .subLight
                          )
                          .padding(.horizontal, 8)
                          .padding(.vertical, 4)
                          .background(
                            Rectangle()
                                .foregroundColor(
                                    remainingStopsToBoarding == 1 ? .subNormal : .primaryHeavy
                                )
                                .cornerRadius(15)
                          )
                      
                      Spacer()
                  }
                  .border(.yellow)
              }
              
              //TODO: 여기에 로티,이미지 파일 들어가야함
              Rectangle()
                  .cornerRadius(10)
                  .foregroundStyle(.subPoint)
                  .frame(width: 200, height: 200)
          }
          .padding(.horizontal, 40)
      }
        
  }
}

#Preview {
    BeforeRideCard(waitingStopName: "포항역", waitingBusNO: "122", remainingStopsToBoarding: .constant(1), remainingTimeToBoarding: 3)
}
