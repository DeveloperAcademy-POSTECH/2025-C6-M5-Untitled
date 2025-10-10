//
//  ETA.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct ETA: View {
    var journey: Journey
    var isFirstCard: Bool
    // estimatedArrivalTime = 현재 시간 + totalTime
    var estimatedArrivalTime: String {
        let arrival = Date().addingTimeInterval(TimeInterval(journey.totalTime * 60))
        return arrival.formatted(date: .omitted, time: .shortened)
    }
    
    var body: some View {
        HStack{
            VStack(alignment:.leading){
                Text("\(journey.totalTime) 분")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text("\(estimatedArrivalTime) 도착 예정")
            }
            if isFirstCard {
                ZStack{
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(.black)
                        .frame(width: 80, height: 35)
                    Text("추천")
                        .foregroundColor(.white)
                }
                .padding(.leading, 70)
            }
        }
    }
}
