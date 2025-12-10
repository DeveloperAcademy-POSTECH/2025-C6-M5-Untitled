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
                            .padding(.horizontal,32)
                            .padding(.vertical, 24)
                    }
                    
                }
                .frame(height: 128)
                
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
                                
                                guard
                                    let journey = JourneyManager.shared.selectedJourney,
                                    let currentIndex = JourneyManager.shared.journeyIndex,
                                    currentIndex < journey.nodes.count
                                else { return }
                                
                                let nextIndex = currentIndex
                                let nextNode = journey.nodes[nextIndex]
                                
                                switch nextNode {
                                case .bus(let busNode):
                                    // 다음 버스 기다리는 상태
                                    let boardingStopName = busNode.start.name
                                    Task {
                                        await ProgressLiveActivityManager.shared.updateStage(
                                            nextStage: RouteStage.waitingForBus.rawValue,
                                            nextDestination: boardingStopName,
                                            totalDistance: 0,
                                            remainingBusStops: busNode.stations.count,
                                            busTravelTime: busNode.travelTime
                                        )
                                    }
                                    print("[DEBUG] OnRideView - 환승 waitingForBus 업데이트, destination: \(boardingStopName)")
                                    
                                case .walk(let walkNode):
                                    if nextIndex == journey.nodes.count - 1 {
                                        // 마지막 도보 → 목적지
                                        Task {
                                            await ProgressLiveActivityManager.shared.updateStage(
                                                nextStage: RouteStage.walkingToDestination.rawValue,
                                                nextDestination: walkNode.end.name,
                                                totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                                                remainingBusStops: 0,
                                                busTravelTime: 0
                                            )
                                        }
                                        print("[DEBUG] OnRideView - walkingToDestination 업데이트, destination: \(walkNode.end.name)")
                                    } else {
                                        // 환승을 위한 도보 → 다음 승차 정류장
                                        Task {
                                            await ProgressLiveActivityManager.shared.updateStage(
                                                nextStage: RouteStage.walkingToBus.rawValue,
                                                nextDestination: walkNode.end.name,
                                                totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                                                remainingBusStops: 0,
                                                busTravelTime: 0
                                            )
                                        }
                                        print("[DEBUG] OnRideView - 환승 walkingToBus 업데이트, destination: \(walkNode.end.name)")
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
                    
                    // TAGO 컨텍스트 설정 (BeforeRideView에서 이미 설정했지만 확인)
                    Task { @MainActor in
                        let arrival = ArrivalInfoManager.shared
                        proximityManager.applyTagoContext(
                            cityCode: arrival.lastCityCode,
                            routeId: arrival.trackedBusRouteIdPublic,
                            targetVehicleNo: arrival.trackedVehicleNoPublic
                        )
                    }
                    
                    // busLegIndex 설정
                    guard
                        let journey = coordinator.journeyManager.selectedJourney,
                        let nodeIndex = coordinator.journeyManager.journeyIndex,
                        let leg = journey.busLegIndex(forNodeIndex: nodeIndex)
                    else { return }
                    
                    viewModel.busLegIndex = leg
                    
                    print("[OnRideView] 탑승 화면 진입 - 기존 추적 계속 진행 (progress: \(proximityManager.progress), remaining: \(proximityManager.remainingStations))")
//                    
//                    // Live Activity 업데이트 (onBus 단계로)
//                    if let busNode = journey.busSegments[safe: leg] {
//                        Task {
//                            await ProgressLiveActivityManager.shared.updateStage(
//                                nextStage: RouteStage.onBus.rawValue,
//                                nextDestination: busNode.end.name,
//                                totalDistance: 10,
//                                remainingBusStops: proximityManager.remainingStations,
//                                busTravelTime: busNode.travelTime
//                            )
//                            print("[DEBUG] OnRideView - onBus 업데이트 완료")
//                        }
//                    }
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
                        print("[OnRideView] journeyIndex 변경 감지 - busLegIndex: \(leg)")
                    }
                }
                .onDisappear {
                    proximityManager.disableVoiceAnnouncement()
                    proximityManager.stop()
                    print("[OnRideView] 화면 종료 - 추적 중단")
                }
            }
        }
    }
}
