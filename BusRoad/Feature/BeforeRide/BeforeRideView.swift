//  BusRoad
//
//  Created by 박난 on 9/23/25.
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
                            .padding(.horizontal,32)
                            .padding(.vertical, 24)
                    }
                }
                .frame(height: 128)
                
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
                                BusPassedCard(busNo: "이전")
                                    .padding(.horizontal, 24.wScaled)
                                    .padding(.top, 28.wScaled)
                                    .padding(.bottom, 30.wScaled)
                            }
                            
                            HStack {
                                
                                Button {
                                    viewModel.acknowledgeMiss()
                                } label: {
                                    Text("놓쳤어요")
                                        .foregroundColor(.subPoint)
                                        .font(.premed28Scaled)
                                        .frame(width: 162.wScaled, height: 64)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.subPoint, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button {
                                    Task { @MainActor in
                                        
                                        let arrival = ArrivalInfoManager.shared
                                        proximityManager.applyTagoContext(
                                            cityCode: arrival.lastCityCode,
                                            routeId: arrival.trackedBusRouteIdPublic,
                                            targetVehicleNo: arrival.trackedVehicleNoPublic
                                        )
                                        viewModel.stopRefreshing()
                                        coordinator.advanceJourneyStage()
                                            
                                        if let index = viewModel.index, let journey = viewModel.journey,
                                            case let .bus(busnode) = journey.nodes[index] {
                                            await ProgressLiveActivityManager.shared.updateStage(
                                                nextStage: RouteStage.onBus.rawValue,
                                                nextDestination: busnode.end.name,
                                                totalDistance: 10,
                                                remainingBusStops: proximityManager.remainingStations,
                                                busTravelTime: busnode.travelTime
                                            )
                                        }
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
                                    viewModel: viewModel,
                                    waitingStopName: busNode.stations[0].stationName,
                                    waitingBusNo: busNode.busNo
                                )
                                .padding(.horizontal, 24.wScaled)
                                .padding(.top, 28.wScaled)
                                .padding(.bottom, 30.wScaled)
                            }
                            Button {
                                Task { @MainActor in
                                    
                                    let arrival = ArrivalInfoManager.shared
                                    proximityManager.applyTagoContext(
                                        cityCode: arrival.lastCityCode,
                                        routeId: arrival.trackedBusRouteIdPublic,
                                        targetVehicleNo: arrival.trackedVehicleNoPublic
                                    )
                                    viewModel.stopRefreshing()
                                    coordinator.advanceJourneyStage()
                                    
                                    if let index = viewModel.index, let journey = viewModel.journey,
                                        case let .bus(busnode) = journey.nodes[index] {
                                        await ProgressLiveActivityManager.shared.updateStage(
                                            nextStage: RouteStage.onBus.rawValue,
                                            nextDestination: busnode.end.name,
                                            totalDistance: 10,
                                            remainingBusStops: proximityManager.remainingStations,
                                            busTravelTime: busnode.travelTime
                                        )
                                    }
                                }
                            } label: {
                                Text("탔어요")
                                    .font(.premed32)
                                    .foregroundStyle(.subLight)
                                    .frame(width: 344.wScaled, height: 64)
                                    .background(.subPoint)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.prepareData()
            }
            
            proximityManager.configure(busLegIndex: 0)
            proximityManager.disableVoiceAnnouncement()
            Task {
                   do {
                       try await proximityManager.start()  
                       print("[BeforeRideView] GPS 추적 시작 성공")
                   } catch {
                       print("[BeforeRideView] GPS 추적 시작 실패: \(error)")
                   }
               }
            
            if let journey = viewModel.journey,
                let index = viewModel.index,
                case let .bus(busNode) = journey.nodes[index] {
                
                // Live Activity를 waitingForBus 단계로 업데이트하는 로직 추가
                Task {
                    await ProgressLiveActivityManager.shared.updateStage(
                        nextStage: "waitingForBus", // RouteStage.waitingForBus.rawValue
                        nextDestination: busNode.start.name,  // 승차 정류장 이름
                        totalDistance: 0,
                        remainingBusStops: proximityManager.remainingStations, 
                        busTravelTime: busNode.travelTime
                    )
                    print("[DEBUG] BeforeRideView - Live Activity waitingForBus 업데이트 완료. Destination: \(busNode.start.name)")
                }
            }
            print("[BeforeRideView] 정류장 추적 시작")
        }
        .onDisappear {
            viewModel.endManager()
        }
    }
}
