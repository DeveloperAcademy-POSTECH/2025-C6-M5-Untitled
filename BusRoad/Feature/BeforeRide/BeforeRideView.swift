//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct BeforeRideView: View {
    @StateObject private var viewmodel = BeforeRideViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    var journey: Journey?
    var index: Int?
    
    init(manager: JourneyManager = .shared) {   // TODO: 의존성 문제 해결(manager viewModel로 빼기)
        if let journey = manager.selectedJourney, let index = manager.journeyIndex {
            self.journey = journey
            self.index = index
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            TopBar(isMoving: true) { coordinator.popToRoot() }
            
            if let journey, let index {
                WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: true)
            }
            
            LineDivider()
            
            ZStack {
                Color(.background)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let journey, let index, case let .bus(busNode) = journey.nodes[index] {
                        BeforeRideCard(
                            waitingStopName: busNode.stations[0].stationName,
                            waitingBusNO: busNode.busNo,
                            remainingStopsToBoarding: .constant(1),
                            remainingTimeToBoarding: 1
                        )
                    }
                    
//                    if viewmodel.remainingStops == 1 {
                        Button {
                            coordinator.advanceJourneyStage()
                        } label: {
                            Text("탔어요")
                                .font(.premed32)
                                .foregroundStyle(.subLight)
                                .frame(width: 239, height: 74)
                                .background(.subStrong)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
//                    } else {
//                        Button {
//                            // TODO: 비활성화 상태에서의 동작(토스트/알럿/햅틱 등)
//                            // “1정류장 남으면 버튼이 활성화돼요”
//                        } label: {
//                            Text("탔어요")
//                                .font(.premed32)
//                                .foregroundStyle(.subNeutral)
//                                .frame(width: 239, height: 74)
//                                .background(.subDisable)
//                                .cornerRadius(20)
//                        }
//                    }
                }
            }
        }
    }
}

#Preview {
    BeforeRideView()
}
