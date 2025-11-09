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
                                        
                                        //  탑승 정류장 통과 처리
                                        proximityManager.markBoardingStationPassed()
                                        
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
                                            print("[DEBUG] BeforeRideView - onBus 업데이트, destination: \(busnode.end.name), remaining: \(proximityManager.remainingStations)")
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
                                    waitingStopName: busNode.stations[0].stationName,
                                    waitingBusNo: busNode.busNo
                                )
                                .padding(.horizontal, 24.wScaled)
                                .padding(.top, 28.wScaled)
                                .padding(.bottom, 30.wScaled)
                            }
                            Button {
                                Task { @MainActor in
                                    // 추가된 로직: 탑승 정류장 통과 처리
                                    proximityManager.markBoardingStationPassed()
                                    
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
                                        print("[DEBUG] BeforeRideView (두번째) - onBus 업데이트, destination: \(busnode.end.name), remaining: \(proximityManager.remainingStations)")
                                    }
                                    viewModel.stopRefreshing()
                                }
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
                case let .bus(busNode) = journey.nodes[index] { 
                viewModel.startRefreshing(for: busNode)
                
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
