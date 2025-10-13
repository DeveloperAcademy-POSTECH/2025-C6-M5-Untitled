//
//  ETA.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct ETA: View {
  var journey: Journey
  // estimatedArrivalTime = 현재 시간 + totalTime
  var estimatedArrivalTime: String {
    let arrival = Date().addingTimeInterval(TimeInterval(journey.totalTime * 60))
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: arrival)
  }
  
  var timeText: String {
    let hours = journey.totalTime / 60
    let minutes = journey.totalTime % 60
    return hours > 0 ? "\(hours)시간 \(minutes)분" : "\(minutes)분"
  }
  
  var body: some View {
    HStack{
      VStack(alignment:.leading){
        Text(timeText)
          .font(.presemi32)
          .foregroundColor(.subLight)
          .padding(.top, 50)
        Text("\(estimatedArrivalTime) 도착 예정")
          .foregroundColor(Color.greyDisable)
      }
        Spacer()
        ZStack{
          RoundedRectangle(cornerRadius: 10)
            .foregroundColor(Color.primaryLight)
            .frame(width: 100, height: 40)
          Text(journey.routeType)
            .foregroundColor(.primaryStrong)
            .font(.presemi20)
        }
        .padding(.trailing, 20)
    }
  }
}
