import SwiftUI

// MARK: - 음성 검색 뷰
struct VoiceSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject private var vm: VoiceSearchViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - 초기화 (TextSearchViewModel 주입)
    init(textSearchVM: TextSearchViewModel,
         onSearchCompleted: @escaping (String) -> Void) {
        _vm = StateObject<VoiceSearchViewModel>(wrappedValue: VoiceSearchViewModel(textSearchVM: textSearchVM))
        self.onSearchCompleted = onSearchCompleted
    }
    private let onSearchCompleted: (String) -> Void

    var body: some View {
        ZStack {
            backgroundGradient

            VStack {
                Spacer()
                // 가운데 메시지
                Text(vm.centerMessage)
                    .font(.title2.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
//                    .animation(.easeInOut(duration: 0.25), value: vm.state)
//                    .animation(.easeInOut(duration: 0.25), value: vm.recognizedText)

                Spacer()

                // 마이크 + 파동
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
//                    .disabled(!vm.isMicButtonEnabled)
                    .scaleEffect(vm.isMicButtonEnabled ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.state)
                }
                .padding(.bottom, 60)
                .animation(.easeInOut(duration: 0.25), value: vm.showWaveAnimation)
            }
            .padding(.horizontal, 32)

            // 우상단 닫기
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
            vm.onSearchCompleted = { text in
                onSearchCompleted(text) // 네비게이터 쪽에서 pop
            }
            vm.onDismiss = { coordinator.pop() }
            vm.onAppear()
        }
        .onDisappear { vm.stopListening() }
    }
}

// MARK: - 서브뷰: 파동
private struct WaveRingsView: View {
    @State private var s1: CGFloat = 0.001
    @State private var s2: CGFloat = 0.001
    @State private var s3: CGFloat = 0.001

    // 각 원의 기본 투명도(겹칠수록 조금 진하게)
    private let a1: CGFloat = 0.22
    private let a2: CGFloat = 0.28
    private let a3: CGFloat = 0.34

    // 크기/속도
    private let baseSize: CGFloat = 120
    private let maxScale: CGFloat = 2.1
    private let duration: Double = 2.0

    var body: some View {
        ZStack {
            ring(scale: s1, baseAlpha: a1)
            ring(scale: s2, baseAlpha: a2)
            ring(scale: s3, baseAlpha: a3)
        }
        .frame(width: baseSize, height: baseSize)
        .onAppear { start() }
        .onDisappear { reset() } // 사라질 때 깔끔히 정리(다음에 자연스레 재시작)
    }

    // 꽉찬 원(스케일 ↑, 커질수록 서서히 사라짐)
    private func ring(scale: CGFloat, baseAlpha: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(baseAlpha))
            .scaleEffect(scale)
            // 커질수록 페이드아웃(0~1 범위로 클램프)
            .opacity(max(0.0, min(1.0, (maxScale + 0.2) - scale)))
    }

    private func start() {
        // 초기값(작게)
        s1 = 0.001; s2 = 0.001; s3 = 0.001

        // 1번 파동
        withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
            s1 = maxScale
        }
        // 2번 파동 약간 지연
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                s2 = maxScale
            }
        }
        // 3번 파동 더 지연
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) {
            withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                s3 = maxScale
            }
        }
    }

    private func reset() {
        // 반복 애니메이션은 뷰가 사라지면 자동 정지.
        // 다음 등장 때 깔끔히 시작되도록 살짝 줄이며 투명해지게.
        withAnimation(.easeOut(duration: 0.2)) {
            s1 = 0.001; s2 = 0.001; s3 = 0.001
        }
    }
}

// MARK: - 계산 프로퍼티
private extension VoiceSearchView {
    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.green.opacity(0.8),
                Color.green.opacity(0.6),
                Color.green.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    var micButtonColor: Color {
        switch vm.state {
        case .ready, .failed: return Color.white
        case .listening:      return Color.white
        case .processing, .completed: return Color.white
        }
    }
    var micIconColor: Color {
        switch vm.state {
        case .ready, .failed: return .black
        case .listening:      return .black
        case .processing, .completed: return .black
        }
    }
    var micIconName: String {
        switch vm.state {
        case .ready, .failed: return "mic.fill"
        case .listening:      return "mic.fill"
        case .processing:     return "mic.fill"
        case .completed:      return "mic.fill"
        }
    }

    func handleMicButtonTap() {
        switch vm.state {
        case .ready, .failed: vm.retry()
        case .listening, .processing, .completed: break
        }
    }
}

