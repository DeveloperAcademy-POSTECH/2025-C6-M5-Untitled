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
    VStack {
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
      .padding(.horizontal, 40)
      
      HStack{
        Text("\(waitingBusNO)번")
          .font(.presemi32)
          .foregroundStyle(remainingStopsToBoarding == 1 ? .primaryNormal: .subLight)
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .background(
            Rectangle()
              .foregroundColor(remainingStopsToBoarding == 1 ? .subNormal : .primaryHeavy)
              .cornerRadius(15)
          )
        Text(remainingStopsToBoarding == 1 ? "잠시 후 도착" : "\(remainingTimeToBoarding)분 후 도착")
          .font(.premed20)
          .foregroundStyle(remainingStopsToBoarding == 1 ? .subLight : .primaryHeavy)
        Spacer()
      }
      .padding(.horizontal, 40)
      .padding(.top, 20)
      
      //TODO: 여기에 로티,이미지 파일 들어가야함
      /// 버스 탑승 대기 이미지
      Rectangle()
        .cornerRadius(10)
        .foregroundStyle(.subPoint)
        .frame(width: 176, height: 146)
        .padding(.horizontal, 84)
        .padding(.top, 48)
        .padding(.bottom, 50)
      
    }
    
    .padding(.top, 60)
    .padding(.bottom, 45)      .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color(remainingStopsToBoarding == 1 ? .primaryStrong : .primaryLight))
    )
  }
}
