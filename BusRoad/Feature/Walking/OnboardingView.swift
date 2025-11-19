import SwiftUI
import Lottie

struct OnboardingView: View {
    @Binding var isFirstLaunching: Bool
    @ObservedObject var viewModel: WalkingViewModel
    
    var body: some View {
        ZStack(alignment: .bottom){
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(alignment: .center, content: {

                Spacer().frame(height: 100)
                
                //로티 영역
                LottieView(animation: .named("WalkingTutorial"))
                    .playing(loopMode: .loop)
                    .animationSpeed(1.0)
                    .frame(width: 500, height: 500)
                
                VStack(alignment: .center, spacing: 10, content: {
                    Text("화살표 방향에 맞춰")
                        .font(.prebold28)
                        .foregroundStyle(.primarywhite)
                    Text("따라 걸어가세요")
                        .font(.prebold28)
                        .foregroundStyle(.primarywhite)
                })
                .padding(.top, -130)
            
                Spacer()
            })

            Button {
                isFirstLaunching.toggle()
                viewModel.finishedOnboarding = true
                viewModel.tryAnnounceStart()
            } label: {
                Text("확인")
                    .font(.premed32)
                    .foregroundColor(.subLight)
                    .frame(width: 285.wScaled, height: 64.wScaled)
                    .background(Color.subPoint)
                    .cornerRadius(20)
            }
            .padding(.bottom, 44.wScaled)
        }
    }
}

#Preview {
    OnboardingView_PreviewWrapper()
}

private struct OnboardingView_PreviewWrapper: View {
    @State var isFirstLaunching = true
    
    var body: some View {
        OnboardingView(isFirstLaunching: $isFirstLaunching, viewModel: WalkingViewModel())
    }
}
