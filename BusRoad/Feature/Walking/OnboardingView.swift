import SwiftUI

struct OnboardingView: View {
    @Binding var isFirstLaunching: Bool
    @ObservedObject var viewModel: WalkingViewModel
    
    var body: some View {
        ZStack(alignment: .bottom){
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack {
                Spacer()
                
                //로티 영역
                Rectangle()
                    .frame(width: 300.wScaled, height: 400.wScaled)
                
                Spacer()
            }
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
