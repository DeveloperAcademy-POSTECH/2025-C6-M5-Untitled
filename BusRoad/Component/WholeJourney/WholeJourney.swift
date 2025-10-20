//
//  WholeJourney.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct WholeJourney: View {
    var journey: Journey
    var journeyIndex: Int
    var isBeforeRide: Bool
    
    var body: some View {
        ZStack{
            Rectangle()
                .frame(height: 4)
                .foregroundColor(.primaryLight)
                .padding(.horizontal, 2)    // 선 안 보이도록
            HStack{
                ForEach(Array(journey.nodes.enumerated()), id: \.element.id) { index, node in
                    if index == journeyIndex {  // 활성 상태
                        if isBeforeRide {
                            BlinkingRouteCircle(routeNode: node)
                        } else {
                            RouteCircle(status: .active, routeNode: node)
                        }
                    } else {                    // 비활성 상태
                        RouteCircle(status: .disable, routeNode: node)
                    }
                    
                    if index != journey.nodes.count - 1 {   // 마지막 요소가 아니면 Spacer() 추가
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    WholeJourney(journey: DummyData.journey, journeyIndex: 2, isBeforeRide: true)
}
