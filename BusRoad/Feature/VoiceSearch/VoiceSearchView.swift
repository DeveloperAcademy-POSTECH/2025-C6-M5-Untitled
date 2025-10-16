import SwiftUI

struct VoiceSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject var vm = VoiceSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var onSearchCompleted: ((String) -> Void)? = nil

    var body: some View {
        ZStack {
            Color.primaryNormal
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text(vm.centerMessage)
                    .font(.premed28)
                    .foregroundStyle(.subLight)
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
                                .frame(width: 105, height: 105)
                            Image(systemName: micIconName)
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(micIconColor)
                        }
                    }
                    .disabled(!vm.isMicButtonEnabled) // 준비/실패 외 상태에서는 탭 방지
                }
                .frame(width: 200, height: 200) // 화면 움직이지 않도록 frame 값
                .padding(.bottom, 114)
            }

            // 닫기 버튼
            VStack {
                HStack {
                    Spacer()
                    Button { vm.dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.primaryWhite)
                            .padding(12)
                            .bold() // 이 친구들도 크기 어떻게 할건지..?
                    }
                    .padding(.top, 13)
                    .padding(.trailing, 24)
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
