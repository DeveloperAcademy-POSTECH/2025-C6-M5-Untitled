import SwiftUI

extension VoiceSearchView {
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
        case .ready, .failed, .listening, .processing, .completed: return .white
        }
    }

    var micIconColor: Color {
        switch vm.state {
        case .ready, .failed, .listening, .processing, .completed: return .black
        }
    }

    var micIconName: String {
        "mic.fill"
    }
}
