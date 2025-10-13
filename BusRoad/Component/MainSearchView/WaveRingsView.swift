import SwiftUI

struct WaveRingsView: View {
    @State private var animationTrigger = false
    
    // 디자인 스펙
    private let baseSize: CGFloat = 105
    private let maxScale: CGFloat = 312 / 105  // 최대 스케일
    private let duration: Double = 3.0
    private let ringCount: Int = 2  // 링 개수
    private let waveInterval: Double = 0.8  // 파동 간격
    
    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { index in
                WaveRing(
                    maxScale: maxScale,
                    duration: duration,
                    delay: Double(index) * waveInterval,
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
    @State private var opacity: Double = 0.4
    
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
