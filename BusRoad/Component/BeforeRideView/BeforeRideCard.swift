//
//  Card.swift
//  C6test
//
//  Created by 강진 on 10/1/25.
//

import SwiftUI
import Lottie


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
              
              VStack(spacing: 20.wScaled) {
                  VStack(spacing: 28.wScaled) {
                      HStack {
                          VStack(alignment: .leading, spacing: 8.wScaled) {
                              Text(waitingStopName)
                                  .font(.prebold36Scaled)
                                  .foregroundStyle(remainingStopsToBoarding == 1 ? .subLight : .primaryHeavy)
                              
                              Text("정류장에서 타야 해요.")
                                  .font(.prereg24Scaled)
                                  .foregroundStyle(remainingStopsToBoarding == 1 ? .subLight : .primaryHeavy)
                          }
                          Spacer()
                      }
                      
                      HStack{
                          Text("\(waitingBusNO)")
                              .font(.presemi32Scaled)
                              .foregroundStyle(
                                remainingStopsToBoarding == 1 ? .primaryNormal: .subLight
                              )
                              .padding(.horizontal, 8.wScaled)
                              .padding(.vertical, 4.wScaled)
                              .background(
                                Rectangle()
                                    .foregroundColor(
                                        remainingStopsToBoarding == 1 ? .subNormal : .primaryHeavy
                                    )
                                    .cornerRadius(15)
                              )
                          
                          Spacer()
                      }
                  }
                  
                  //TODO: 여기에 로티,이미지 파일 들어가야함
                  LottieView(animation: .named("BeforeRiding"))
                    .playing(loopMode: .loop)  // 반복 재생
                    .animationSpeed(1.0)  // 재생 속도
                    .frame(width: 200.wScaled, height: 200.wScaled)

                     
              }
              .padding(.horizontal, 40.wScaled)
      }
  }
}

#Preview {
    BeforeRideCard(waitingStopName: "포항역", waitingBusNO: "122", remainingStopsToBoarding: .constant(1), remainingTimeToBoarding: 3)
}
