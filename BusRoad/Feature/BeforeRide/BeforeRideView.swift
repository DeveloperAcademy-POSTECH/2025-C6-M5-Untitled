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
                    
                    if viewModel.hasPassed {
                        
                        VStack(spacing: 0) {
                            if let passedBus = viewModel.lastPassedBusNo {
                                BusPassedCard(busNo: passedBus)
                                    .padding(.horizontal, 24.wScaled)
                                    .padding(.top, 28.wScaled)
                                    .padding(.bottom, 30.wScaled)
                            } else {
                                // 예외 처리 (버스 번호 없을 때)
                                BusPassedCard(busNo: "이전")
                                    .padding(.horizontal, 24.wScaled)
                                    .padding(.top, 28.wScaled)
                                    .padding(.bottom, 30.wScaled)
                            }
                            
                            HStack {
                                
                                Button {
                                    viewModel.hasPassed = false
                                } label: {
                                    Text("놓쳤어요")
                                        .foregroundColor(.cancelbutton)
                                        .font(.premed28Scaled)
                                        .frame(width: 162.wScaled, height: 64)
                                        .background(.primaryLight)
                                        .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button {
                                    coordinator.advanceJourneyStage()
                                    
                                    if let index = viewModel.index, let journey = viewModel.journey,
                                       case let .bus(busnode) = journey.nodes[index] {
                                        ProgressLiveActivityManager.shared.updateStage(
                                            nextStage: RouteStage.onBus.rawValue,
                                            nextDestination: busnode.end.name,
                                            totalDistance: 10,
                                            remainingBusStops: proximityManager.remainingStations,
                                            busTravelTime: busnode.travelTime
                                        )
                                    }
                                } label: {
                                    Text("탔어요")
                                        .foregroundColor(.subLight)
                                        .font(.premed28Scaled)
                                        .frame(width: 162.wScaled, height: 64)
                                        .background(.subPoint)
                                        .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal, 24.wScaled)
                            
                        }
                    }
                    else {
                        VStack(spacing: 0) {
                            if let journey = viewModel.journey,
                               let index = viewModel.index,
                               case let .bus(busNode) = journey.nodes[index] {
                                BeforeRideCard(
                                    waitingStopName: busNode.stations[0].stationName,
                                    waitingBusNo: busNode.busNo
                                )
                                .padding(.horizontal, 24.wScaled)
                                .padding(.top, 28.wScaled)
                                .padding(.bottom, 30.wScaled)
                            }
                            Button {
                                
                                //                                if viewModel.isArrivingSoon {
                                // TODO: 활성화상태일때만 되도록 해야하는데 도착정보 없을 경우 예외처리 이슈 나중에 해결하기 전까지는 일단 비활성화 상태에서도 뷰전환되도록
                                coordinator.advanceJourneyStage()
                                
                                if let index = viewModel.index, let journey = viewModel.journey,
                                   case let .bus(busnode) = journey.nodes[index] {
                                    ProgressLiveActivityManager.shared.updateStage(
                                        nextStage: RouteStage.onBus.rawValue,
                                        nextDestination: busnode.end.name,
                                        totalDistance: 10,
                                        remainingBusStops: proximityManager.remainingStations,
                                        busTravelTime: busnode.travelTime
                                    )
                                }
                                viewModel.stopRefreshing()
                                //                                }
                            } label: {
                                Text("탔어요")
                                    .font(.premed32)
                                    .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .subLight)  // 임시 활성화
                                    .frame(width: 344.wScaled, height: 64)
                                    .background(viewModel.isArrivingSoon ? .subPoint : .subPoint)     // 임시 활성화
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear {
            proximityManager.configure(busLegIndex: 0)
            proximityManager.disableVoiceAnnouncement()
            proximityManager.start()
            
            if let journey = viewModel.journey,
               let index = viewModel.index,
               case .bus(let busNode) = journey.nodes[index] {
                viewModel.startRefreshing(for: busNode)
            }
            
            print("[BeforeRideView] 정류장 추적 시작")
            
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }
}

