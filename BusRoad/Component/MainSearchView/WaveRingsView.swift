import SwiftUI

struct WaveRingsView: View {
    @State private var animationTrigger = false
    
    private let baseSize: CGFloat = 105
    private let duration: Double = 2.0
    private let rings: [(scale: CGFloat, delay: Double)] = [
        (312 / 105, 0.0),    // 첫 번째 원: 312까지
        (250 / 105, 0.6)     // 두 번째 원:250까지
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<rings.count, id: \.self) { index in
                WaveRing(
                    maxScale: rings[index].scale,
                    duration: duration,
                    delay: rings[index].delay,
                    animationTrigger: animationTrigger
                )
            }
        }
        .frame(width: baseSize, height: baseSize)
        .onAppear {
            animationTrigger = true
        }
        .onDisappear {
            animationTrigger = false
        }
    }
}

struct WaveRing: View {
    let maxScale: CGFloat
    let duration: Double
    let delay: Double
    let animationTrigger: Bool
    
    @State private var scale: CGFloat = 0.001
    @State private var opacity: Double = 0.2
    
    var body: some View {
        Circle()
            .fill(Color.subNormal)
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: animationTrigger) { _, newValue in
                if newValue {
                    startAnimation()
                } else {
                    reset()
                }
            }
    }
    
    private func startAnimation() {
        // 지연 후 애니메이션 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateWave()
        }
    }
    
    private func animateWave() {
        guard animationTrigger else { return }
        
        // 초기화
        scale = 0.001
        opacity = 0.4
        
        // 확장 + 페이드아웃
        withAnimation(.easeOut(duration: duration)) {
            scale = maxScale
            opacity = 0.0
        }
        
        // 애니메이션 끝나면 다시 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            animateWave()
        }
    }
    
    private func reset() {
        scale = 0.001
        opacity = 0.0
    }
}

// MARK: - Preview
struct WaveRingsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.primaryNormal
                .ignoresSafeArea()
            
            WaveRingsView()
            Circle()
                .foregroundColor(.subNormal)
                .frame(width: 105, height: 105)
            Image(systemName: "microphone.fill")
                .font(.title)
        }
    }
}
