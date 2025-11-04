//
//  BusPassedCard.swift
//  BusRoad
//
//  Created by 박난 on 11/4/25.
//
import SwiftUI
import Lottie


struct BusPassedCard: View {
    var busNo: String
    
    var body: some View {
            ZStack {
                Rectangle()
                    .foregroundColor(.primaryStrong)
                    .cornerRadius(20)
                
                VStack(spacing: 0) {
                    Text("버스에 탑승하셨나요?")
                        .font(.prebold30Scaled)
                        .foregroundStyle(.subLight)
                    
                    Spacer()
                        .frame(height: 12.wScaled)
                    
                    Text("\(busNo) 버스가 지나갔어요")
                        .font(.premed24Scaled)
                        .foregroundStyle(.subLight)
                }
            }
        
    }
}
