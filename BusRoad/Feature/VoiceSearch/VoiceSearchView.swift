import SwiftUI

struct VoiceSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject var vm = VoiceSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var onSearchCompleted: ((String) -> Void)?

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
                            Image("big-mic")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(!vm.isMicButtonEnabled) // 준비/실패 외 상태에서는 탭 방지
                }
                .frame(width: 200, height: 200) // 화면 움직이지 않도록 frame 값
                .padding(.bottom, 114.wScaled)
            }

            // 닫기 버튼
            VStack {
                HStack {
                    Spacer()
                    Button { vm.dismiss() } label: {
                        Image("xbutton-white")
                            .frame(width: 44, height: 44)
                            .aspectRatio(contentMode:.fit)
                            .foregroundColor(.primarywhite)
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
