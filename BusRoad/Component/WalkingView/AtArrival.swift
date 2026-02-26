import SwiftUI
import Lottie

struct AtArrival: View {
    var journey: Journey
    var index: Int
    @EnvironmentObject var coordinator: NavigationCoordinator
    @ObservedObject var viewModel: WalkingViewModel
    
    var body: some View {
        if case let .walk(node) = journey.nodes[index] {
            VStack(spacing: 55) {
                
                // 체크 애니메이션
                HStack {
                    Spacer()
                    LottieView(animation: .named("check"))
                        .playing(loopMode: .playOnce)
                        .animationDidFinish { _ in
                            withAnimation(.easeIn(duration: 0.6)) {
                                viewModel.showArrivalContent = true
                            }
                        }
                        .animationSpeed(1.0)
                        .frame(width: 180, height: 180)
                    Spacer()
                }
                
                // 하단 텍스트
                VStack(spacing: 11) {
                    
                    Text("정류장 이름이 맞는지")
                        .font(.prereg24Scaled)
                        .foregroundColor(.primaryHeavy)
                    
                    Text("확인해주세요")
                        .font(.prereg24Scaled)
                        .foregroundColor(.primaryHeavy)
                }
                .opacity(viewModel.showArrivalContent ? 1 : 0)
            }
            .padding(.horizontal, 32.wScaled)
            .onAppear {
                viewModel.manuallyArrived = true
            }
            
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36Scaled)
                .foregroundColor(.red)
        }
    }
}
