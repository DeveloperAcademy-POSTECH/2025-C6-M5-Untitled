import SwiftUI

struct VoiceSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject var vm = VoiceSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var onSearchCompleted: ((String) -> Void)? = nil

    var body: some View {
        ZStack {
            backgroundGradient

            VStack {
                Spacer()

                Text(vm.centerMessage)
                    .font(.title2.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer()

                ZStack {
                    if vm.showWaveAnimation {
                        WaveRingsView()
                    }
                    Button(action: handleMicButtonTap) {
                        ZStack {
                            Circle()
                                .fill(micButtonColor)
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            Image(systemName: micIconName)
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(micIconColor)
                        }
                    }
                    // 듣는 중/처리 중에는 살짝 눌린 느낌
                    .scaleEffect(vm.isMicButtonEnabled ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.state)
                    .disabled(!vm.isMicButtonEnabled) // 준비/실패 외 상태에서는 탭 방지
                }
                .padding(.bottom, 60)
                .animation(.easeInOut(duration: 0.25), value: vm.showWaveAnimation)
            }
            .padding(.horizontal, 32)

            // 닫기 버튼
            VStack {
                HStack {
                    Spacer()
                    Button { vm.dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 1) 완료 시: 외부 콜백(있으면) -> pop
            vm.onSearchCompleted = { text in
                onSearchCompleted?(text)
                coordinator.pop()
            }
            // 2) 닫기(X) 시 pop
            vm.onDismiss = { coordinator.pop() }
            // 3) 실제 리스닝 시작/바인딩
            vm.onAppear()
        }
        .onDisappear {
            vm.stopListening()
        }
    }
}
