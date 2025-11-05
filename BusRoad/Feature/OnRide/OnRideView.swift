import SwiftUI

struct OnRideView: View {
    @StateObject private var viewModel = OnRideViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject var proximityManager: AlightProximityManager
    
    var body: some View {
        ZStack {
            Color(.primarywhite)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 상단 고정 영역
                VStack(spacing: 0) {
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey = viewModel.journey, let index = viewModel.index {
                        WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: false)
                            .padding(32)
                    }
                    
                }
                .frame(height: 144)
                
                LineDivider()
                
                // 하단 영역
                ZStack {
                    Color(.background)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        OnRideCard(
                            busStopName: viewModel.stopName,
                            canAlight: proximityManager.canAlight,
                            progress: proximityManager.progress,
                            remainingStations: proximityManager.remainingStations,
                            hasArrived: proximityManager.hasArrived
                        )
                        .padding(.horizontal, 24.wScaled)
                        .padding(.top, 28.wScaled)
                        .padding(.bottom, 30.wScaled)
                        
                        // 버튼 영역
                        if proximityManager.canAlight {
                            Button {
                                proximityManager.stop()
                                coordinator.advanceJourneyStage()
                                
                                let journey = JourneyManager.shared.selectedJourney
                                
                                if let journey = JourneyManager.shared.selectedJourney,
                                   let currentIndex = JourneyManager.shared.journeyIndex,
                                   currentIndex < journey.nodes.count - 1 {
                                    
                                    if let index = viewModel.index, let journey = viewModel.journey,
                                       case let .bus(busnode) = journey.nodes[index + 1] {
                                        ProgressLiveActivityManager.shared.updateStage(
                                            nextStage: RouteStage.waitingForBus.rawValue,
                                            nextDestination: busnode.end.name,
                                            totalDistance: 0,
                                            remainingBusStops: proximityManager.remainingStations,
                                            busTravelTime: busnode.travelTime
                                        )
                                    } else if let index = viewModel.index, let journey = viewModel.journey,
                                              case let .walk(node) = journey.nodes[index + 1] {
                                        if journey.nodes.count - 1 == index + 1{
                                            ProgressLiveActivityManager.shared.updateStage(
                                                nextStage: RouteStage.walkingToDestination.rawValue,
                                                nextDestination: node.end.name,
                                                totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                                                remainingBusStops: 0,
                                                busTravelTime: 0
                                            )
                                        } else {
                                            ProgressLiveActivityManager.shared.updateStage(
                                                nextStage: RouteStage.walkingToBus.rawValue,
                                                nextDestination: node.end.name,
                                                totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                                                remainingBusStops: 0,
                                                busTravelTime: 0
                                            )
                                        }
                                    }
                                }
                                
                            } label: {
                                Text("내렸어요")
                                    .font(.premed32)
                                    .foregroundStyle(.subLight)
                                    .frame(width: 344.wScaled, height: 64)
                                    .background(.subPoint)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                        } else {
                            Button {
                                // TODO: 비활성화 상태에서의 동작(토스트 등)
                                // "1정류장 남으면 버튼이 활성화돼요"
                            } label: {
                                Text("내렸어요")
                                    .foregroundColor(.subNeutral)
                                    .font(.premed32)
                                    .frame(width: 344.wScaled, height: 64)
                                    .background(.subDisable)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                        }
                    }
                }
                .onAppear {
                    proximityManager.enableVoiceAnnouncement()
                    
                    guard
                        let journey = coordinator.journeyManager.selectedJourney,
                        let nodeIndex = coordinator.journeyManager.journeyIndex,
                        let leg = journey.busLegIndex(forNodeIndex: nodeIndex)
                    else { return }
                    
                    viewModel.busLegIndex = leg
                }
                .onReceive(coordinator.journeyManager.$journeyIndex) { _ in
                    guard
                        let j = coordinator.journeyManager.selectedJourney,
                        let nodeIdx = coordinator.journeyManager.journeyIndex,
                        let leg = j.busLegIndex(forNodeIndex: nodeIdx)
                    else { return }
                    
                    if viewModel.busLegIndex != leg {
                        viewModel.busLegIndex = leg
                        
                        proximityManager.configure(busLegIndex: leg)
                    }
                }
                .onDisappear {
                    proximityManager.disableVoiceAnnouncement()
                    proximityManager.stop()
                }
            }
        }
    }
}
