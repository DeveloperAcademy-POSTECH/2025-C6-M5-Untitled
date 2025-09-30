import SwiftUI

struct WaveRingsView: View {
    @State private var s1: CGFloat = 0.001
    @State private var s2: CGFloat = 0.001
    @State private var s3: CGFloat = 0.001

    private let a1: CGFloat = 0.22
    private let a2: CGFloat = 0.28
    private let a3: CGFloat = 0.34

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
        .onDisappear { reset() }
    }

    private func ring(scale: CGFloat, baseAlpha: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(baseAlpha))
            .scaleEffect(scale)
            .opacity(max(0.0, min(1.0, (maxScale + 0.2) - scale)))
    }

    private func start() {
        s1 = 0.001; s2 = 0.001; s3 = 0.001

        withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
            s1 = maxScale
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                s2 = maxScale
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) {
            withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                s3 = maxScale
            }
        }
    }

    private func reset() {
        withAnimation(.easeOut(duration: 0.2)) {
            s1 = 0.001; s2 = 0.001; s3 = 0.001
        }
    }
}
