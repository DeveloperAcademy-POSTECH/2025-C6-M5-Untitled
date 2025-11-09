//
//  VerifyingStop.swift
//  BusRoad
//
//  Created by 강진 on 10/14/25.
//

import SwiftUI

struct VerifyingStop: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    var journey: Journey
    var index: Int
    
    var body: some View {
        
        if case let .walk(node) = journey.nodes[index] {
            VStack(alignment: .leading, spacing: 0) {
                
                Spacer()
                
                VStack (alignment: .leading, spacing: 40) {
                    MarqueeText(
                        text: node.end.name,
                        font: .presemi36Scaled,
                        uiFont: .presemi36Scaled,
                        startDelay: 1.0,
                        alignment: .leading
                    )
                    .foregroundColor(.primaryHeavy)
                    
                    Text("정류장 이름이 맞는지\n확인해주세요.")
                        .font(.prereg32Scaled)
                        .foregroundStyle(Color.primaryHeavy)
                }
                .padding(.bottom, 222.wScaled)
            }
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36Scaled)
                .foregroundColor(.red)
        }
    }
}
