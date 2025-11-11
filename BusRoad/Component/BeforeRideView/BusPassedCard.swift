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
        ZStack(alignment: .center, content: {
            
            Rectangle()
                .foregroundColor(.primaryStrong)
                .cornerRadius(20)
                
            VStack(alignment: .center, spacing: 12.wScaled, content: {
                    
                Image("passedBusCharacter")
                    .resizable()
                    .frame(width: 120, height: 97)
                    
                    
                Spacer()
                    .frame(height: 12.wScaled)
                    
                Text("버스에 탑승하셨나요?")
                    .font(.prebold30Scaled)
                    .foregroundStyle(.subLight)
                    
                Text("\(busNo) 버스가 지나갔어요")
                    .font(.premed20Scaled)
                    .foregroundStyle(.subLight)
            })
            .padding(.bottom, 60.wScaled)
        })
        
    }
}

#Preview {
    BusPassedCard(busNo: "급행 5000번")
}
