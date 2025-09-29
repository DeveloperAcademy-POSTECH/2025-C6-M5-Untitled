import SwiftUI

struct VoiceSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject var vm: VoiceSearchViewModel
    @Environment(\.dismiss) private var dismiss

    private let onSearchCompleted: (String) -> Void

    init(mainSearchVM: MainSearchViewModel,
         onSearchCompleted: @escaping (String) -> Void) {
        _vm = StateObject(wrappedValue: VoiceSearchViewModel(mainSearchVM: mainSearchVM))
        self.onSearchCompleted = onSearchCompleted
    }

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
                    .scaleEffect(vm.isMicButtonEnabled ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.state)
                }
                .padding(.bottom, 60)
                .animation(.easeInOut(duration: 0.25), value: vm.showWaveAnimation)
            }
            .padding(.horizontal, 32)

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
            vm.onSearchCompleted = { text in onSearchCompleted(text) }
            vm.onDismiss = { coordinator.pop() }
            vm.onAppear()
        }
        .onDisappear { vm.stopListening() }
    }
}
