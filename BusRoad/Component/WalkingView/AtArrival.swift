import SwiftUI
import Lottie

struct AtArrival: View {
    var journey: Journey
    var index: Int
    @EnvironmentObject var coordinator: NavigationCoordinator
    @ObservedObject var viewModel: WalkingViewModel

    var body: some View {
        if case let .walk(node) = journey.nodes[index] {
            if viewModel.showVerifyingStop && journey.nodes.count > 1 {
                VerifyingStop(
                    journey: journey,
                    index: index
                )
                .padding(.horizontal, 32.wScaled)
                VStack(spacing: 0){
                    Button {
                        coordinator.advanceJourneyStage()
                        viewModel.showVerifyingStop = false
                    } label: {
                        Text("맞아요")
                            .foregroundColor(Color.subLight)
                            .font(.premed32)
                            .frame(width: 344.wScaled, height: 64)
                            .background(Color.subPoint)
                            .cornerRadius(20)
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    Spacer()

                    MarqueeText(
                        text: node.end.name,
                        font: .presemi36Scaled,
                        uiFont: .presemi36Scaled,
                        startDelay: 1.0,
                        alignment: .leading
                    )
                    .foregroundColor(.primaryHeavy)

                    Spacer()

                    HStack {
                        Spacer()
                        LottieView(animation: .named("check"))
                            .playing(loopMode: .playOnce)
                            .animationSpeed(1.0)
                            .frame(width: 180, height: 180)
                        Spacer()
                    }

                    Spacer()

                    Text("도착")
                        .font(.presemi32Scaled)
                        .foregroundColor(.primaryHeavy)
                    Text("했어요!")
                        .font(.prereg32Scaled)
                        .foregroundColor(.primaryHeavy)
                        .padding(.bottom, 80.wScaled)
                }
                .padding(.horizontal, 32.wScaled)
                .onAppear {
                    viewModel.manuallyArrived = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        viewModel.showVerifyingStop = true
                    }
                }
            }
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36Scaled)
                .foregroundColor(.red)
        }
    }
}
