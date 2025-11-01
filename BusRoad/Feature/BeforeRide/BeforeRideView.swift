//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct BeforeRideView: View {
    @StateObject private var viewModel = BeforeRideViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject var proximityManager: AlightProximityManager
    
    var body: some View {
        
        ZStack {
            Color.primarywhite
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                VStack(spacing: 0) {
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey = viewModel.journey, let index = viewModel.index {
                        WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: true)
                            .padding(32)
                    }
                }
                .frame(height: 144)
                
                LineDivider()
                
                ZStack {
                    Color(.background)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        if let journey = viewModel.journey,
                           let index = viewModel.index,
                           case let .bus(busNode) = journey.nodes[index] {
                            BeforeRideCard(
                                waitingStopName: busNode.stations[0].stationName,
                                waitingBusNO: busNode.busNo,
                                remainingStopsToBoarding: .constant(1),
                                remainingTimeToBoarding: 1
                            )
                            .padding(.horizontal, 24.wScaled)
                            .padding(.top, 28.wScaled)
                            .padding(.bottom, 47.wScaled)
                        }
                        
                        Button {
                            coordinator.advanceJourneyStage()
                            
                            if let index = viewModel.index, let journey = viewModel.journey,
                               case let .bus(busnode) = journey.nodes[index + 1] {
                                ProgressLiveActivityManager.shared.updateStage(
                                    stage: RouteStage.onBus.rawValue,
                                    destination: busnode.end.name,
                                    totalBusStops: busnode.stations.count,
                                    totalDistance: 10
                                )
                            }
                        } label: {
                            Text("탔어요")
                                .font(.premed32)
                                .foregroundStyle(.subLight)
                                .frame(width: 239, height: 74)
                                .background(.subStrong)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .frame(height: 74)
                    }
                }
            }
        }
        .onAppear {
            proximityManager.configure(busLegIndex: 0)
            proximityManager.disableVoiceAnnouncement()
            proximityManager.start()
            
            print("[BeforeRideView] 정류장 추적 시작")
        }
    }
}
