//
//  RouteSummary.swift
//  BusRoad
//
//  Created by 강진 on 10/12/25.
//

import SwiftUI

struct RouteSummary: View {
    var journey: Journey
    var body: some View {
        HStack(spacing: 61.wScaled) {
            VStack(spacing: 6.wScaled) {
                ZStack{
                    Circle()
                        .frame(width: 28.wScaled.minimum(28), height:28.wScaled.minimum(28))
                        .foregroundColor(.subStrong)
                    Image(systemName: "bus.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:17.wScaled.minimum(17), height: 16.wScaled.minimum(16))
                        .foregroundColor(Color.greyLight)
                }
                Text("환승 \(journey.transferCount)회")
                    .font(.prereg16Scaled)
                    .foregroundColor(Color.subLight)
            }
            
            VStack(spacing: 6.wScaled) {
                ZStack{
                    Circle()
                        .frame(width: 28.wScaled.minimum(28), height:28.wScaled.minimum(28))
                        .foregroundColor(Color.greyNormal)
                    Image(systemName: "figure.walk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:12.wScaled.minimum(12), height:16.wScaled.minimum(16))
                    
                        .foregroundColor(Color.greyLight)
                }
                Text("도보 \(journey.walkingTime)분")
                    .font(.prereg16Scaled)
                    .foregroundColor(Color.subLight)
            }
        }
    }
}
