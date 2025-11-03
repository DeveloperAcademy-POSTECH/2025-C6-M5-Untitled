//
//  VerifyingStop.swift
//  BusRoad
//
//  Created by 강진 on 10/14/25.
//

import SwiftUI

struct VerifyingStop: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Binding var showVerifyingStop: Bool
    
    var journey: Journey
    var index: Int
    
    var body: some View {
        Spacer()
        
        if case let .walk(node) = journey.nodes[index] {
            VStack(alignment: .leading) {
                Spacer()
                
                MarqueeText(
                    text: node.end.name,
                    font: .presemi36Scaled,
                    uiFont: .presemi36Scaled,
                    startDelay: 1.0,
                    alignment: .leading,
                )
                .foregroundColor(.primaryHeavy)
                .padding(.top, 20.wScaled)
                
                
                Text("정류장 이름이 맞는지\n확인해주세요.")
                    .font(.prereg32Scaled)
                    .foregroundStyle(Color.primaryHeavy)
                
                Spacer()
                
                HStack{
                    Spacer()
                    Button {
                        coordinator.advanceJourneyStage()
                        showVerifyingStop = false
                        
                        if case let .bus(busnode) = journey.nodes[index + 1] {
                            ProgressLiveActivityManager.shared.updateStage(
                                nextStage: RouteStage.waitingForBus.rawValue,
                                nextDestination: busnode.end.name,
                                totalDistance: 0,
                                remainingBusStops: busnode.stations.count,
                                busTravelTime: busnode.travelTime
                            )
                        }
                    } label: {
                        ZStack{
                            Rectangle()
                                .cornerRadius(20)
                                .foregroundColor(.subStrong)
                                .frame(width: 240.wScaled, height: 75.wScaled)
                            Text("맞아요")
                                .font(.premed32Scaled)
                                .foregroundColor(.subLight)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom,50.wScaled)
            }
            .padding(.horizontal, 30.wScaled)
            
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36Scaled)
                .foregroundColor(.red)
        }
    }
}
