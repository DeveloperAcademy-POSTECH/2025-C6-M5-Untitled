import SwiftUI

struct OnRideView: View {
    @StateObject private var vm = OnRideViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    var journey: Journey?
    var index: Int?
    
    init(manager: JourneyManager = .shared) {
        if let journey = manager.selectedJourney, let index = manager.journeyIndex {
            self.journey = journey
            self.index = index
        }
    }
    
    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()
            
            VStack(spacing: 47) {
                
                if let journey, let index {
                    WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: false)
                }
                
                OnRideCard(
                    busStopName: vm.stopName,
                    canAlight: vm.canAlight,
                    progress: vm.progress
                )
                .padding(.horizontal, 24)
                
//#if DEBUG
//                Button("환승 전체 데모 시작") {
//                    vm.startFullTransferDemo()
//                }
//                .buttonStyle(.borderedProminent)
//#endif
                
                if vm.canAlight {
                    Button {
                        coordinator.advanceJourneyStage()
                    } label: {
                        Text("내렸어요")
                            .font(.premed32)
                            .foregroundStyle(.subLight)
                            .frame(width: 239, height: 74)
                            .background(.subStrong)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        // TODO: 비활성화 상태에서의 동작(토스트 등)
                        // “1정류장 남으면 버튼이 활성화돼요”
                    } label: {
                        Text("내렸어요")
                            .font(.premed32)
                            .foregroundStyle(.subNeutral)
                            .frame(width: 239, height: 74)
                            .background(.subDisable)
                            .cornerRadius(20)
                    }
                }
            }
            .onAppear {
                guard
                    let journey = coordinator.journeyManager.selectedJourney,
                    let nodeIndex = coordinator.journeyManager.journeyIndex,
                    let leg = journey.busLegIndex(forNodeIndex: nodeIndex)
                else { return }
                
                vm.busLegIndex = leg
                vm.start()
            }
            
            .onReceive(coordinator.journeyManager.$journeyIndex) { _ in
                guard
                    let j = coordinator.journeyManager.selectedJourney,
                    let nodeIdx = coordinator.journeyManager.journeyIndex,
                    let leg = j.busLegIndex(forNodeIndex: nodeIdx)
                else { return }
                
                if vm.busLegIndex != leg {
                    vm.busLegIndex = leg
                    vm.start()
                }
            }
            .onDisappear { vm.stop() }
            
        }
    }
}


#Preview {
    OnRideView()
        .environmentObject(NavigationCoordinator())
}
