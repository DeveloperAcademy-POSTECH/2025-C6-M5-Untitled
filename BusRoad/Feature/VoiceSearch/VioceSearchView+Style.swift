import SwiftUI

extension VoiceSearchView {

    var micButtonColor: Color {
        switch vm.state {
        case .ready, .failed, .listening, .processing, .completed: return .subNormal
        }
    }

    var micIconColor: Color {
        switch vm.state {
        case .ready, .failed, .listening, .processing, .completed: return .primaryNormal
        }
    }

    var micIconName: String {
        "mic.fill"
    }
}
