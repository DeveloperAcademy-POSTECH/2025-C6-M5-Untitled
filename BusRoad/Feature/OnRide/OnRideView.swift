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
        VStack(spacing: 0) {
            
            TopBar(isMoving: true) { coordinator.popToRoot() }
            
            if let journey, let index {
                WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: false)
            }
            
            LineDivider()
            
            ZStack {
                Color(.background)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    OnRideCard(
                        busStopName: vm.stopName,
                        remainingStops: vm.remainingStops,
                        progress: vm.progress
                    )
                    
                    if vm.remainingStops <= 1 {
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
                            // TODO: 비활성화 상태에서의 동작(토스트/알럿/햅틱 등)
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
            }
        }
    }
}


#Preview {
    OnRideView()
}
