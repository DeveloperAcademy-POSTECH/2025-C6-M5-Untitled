//
//  ETA.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct ETA: View {
    var journeys: [Journey]
    var journey: Journey
    var index: Int
    
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

        let base: String
        if hours > 0 && minutes > 0 {
            base = "\(hours)시간 \(minutes)분"
        } else if hours > 0 {
            base = "\(hours)시간"
        } else {
            base = "\(minutes)분"
        }

        // ✅ 도보-only면 "도보 " 붙임
        return journey.isWalkingOnly ? "도보 \(base)" : base
    }
    
    var isMinimumTransfer: Bool {
        journey.transferCount == journeys.map(\.transferCount).min()
    }
    
    var isMinimumWalking: Bool {
        journey.walkingTime == journeys.map(\.walkingTime).min()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4.wScaled) {
            HStack{
                if index == 0  {
                    Text("최적")
                        .foregroundColor(.subPoint)
                        .font(.presemi20Scaled)
                    
                } else if isMinimumWalking {
                    
                    
                    Text(" ")
                        .foregroundColor(.primaryStrong)
                        .font(.presemi20Scaled)
                    
                } else if isMinimumTransfer {
                    Text(" ")
                        .foregroundColor(.primaryStrong)
                        .font(.presemi20Scaled)
                }
            }
            
            Text(timeText)
                .font(.presemi32Scaled)
                .foregroundColor(.primaryHeavy)
            
            Text("\(estimatedArrivalTime) 도착 예정")
                .foregroundColor(Color.greyNormal)
                .font(.prereg16Scaled)
        }
    }
}
