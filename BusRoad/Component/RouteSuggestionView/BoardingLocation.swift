//
//  BoardingLocation.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct BoardingLocation: View {
    var route: BusRouteNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24.wScaled){
            
            VStack(alignment: .leading, spacing: 8.wScaled) {
                Text("탑승 정류장")
                    .font(.prereg20Scaled)
                    .foregroundColor(Color.subLight)
                
                MarqueeText(
                    text: route.start.name,
                    font: .presemi32Scaled,
                    uiFont: .presemi32Scaled,
                    startDelay: 1.0,
                    alignment: .leading
                )
                .foregroundColor(Color.subLight)
            }
           
            HStack(spacing: 8.wScaled) {
                Text("\(route.busNo)")
                    .font(.presemi24)
                    .padding(.horizontal, 8.wScaled)
                    .padding(.vertical, 4.wScaled)
                    .background(
                        Rectangle()
                            .cornerRadius(15.wScaled)
                            .foregroundColor(Color.subNormal)
                    )
                // TODO: 실시간 버스 도착 예정 시간으로 수정해야 함!! (실시간 API 활용 필요)
                Text("3분 후 도착")
                    .font(.prereg16Scaled)
                    .foregroundColor(Color.subLight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
