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
        HStack(spacing: 61) {
            VStack(spacing: 6) {
                ZStack{
                    Circle()
                        .frame(width: 28, height:28)
                        .foregroundColor(.subStrong)
                    Image(systemName: "bus.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:13, height: 13)
                        .foregroundColor(Color.greyLight)
                }
                Text("환승 \(journey.transferCount)회")
                    .font(.prereg16)
                    .foregroundColor(Color.subLight)
            }
            
            VStack(spacing: 6) {
                ZStack{
                    Circle()
                        .frame(width: 28, height:28)
                        .foregroundColor(Color.greyNormal)
                    Image(systemName: "figure.walk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:13, height:13)
                        
                        .foregroundColor(Color.greyLight)
                }
                Text("도보 \(journey.walkingTime)분")
                    .font(.prereg16)
                    .foregroundColor(Color.subLight)
            }
        }
    }
}
