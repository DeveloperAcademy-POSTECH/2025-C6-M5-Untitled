//
//  BoardingLocation.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct BoardingLocation: View {
    var route: BusRouteNode
    var isActive: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15.wScaled){
            
            VStack(alignment: .leading, spacing: 4.wScaled) {
                Text("정류장")
                    .font(.prereg20Scaled)
                    .foregroundColor(Color.greyNormal)
                
                MarqueeText(
                    text: route.start.name,
                    font: .presemi24Scaled,
                    uiFont: .presemi24Scaled,
                    startDelay: 1.0,
                    alignment: .leading,
                    shouldAnimate: isActive
                )
                .foregroundColor(Color.primaryHeavy)
            }
            
            VStack(alignment: .leading, spacing: 4.wScaled) {
                
                Text("버스")
                    .font(.prereg20Scaled)
                    .foregroundColor(Color.greyNormal)
                
                HStack(spacing: 8.wScaled) {
                    if !route.busNo.isEmpty {
                            Text(route.busNo[0])
                                .font(.presemi24)
                                .foregroundColor(.primaryHeavy)
                        }
                    // TODO: 실시간 버스 도착 예정 시간으로 수정해야 함!! (실시간 API 활용 필요)
                    Text("곧 도착")
                        .font(.prereg16Scaled)
                        .foregroundColor(Color.greyNormal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
