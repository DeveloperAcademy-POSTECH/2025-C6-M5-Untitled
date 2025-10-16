import SwiftUI

extension VoiceSearchView {
    func handleMicButtonTap() {
        switch vm.state {
        case .ready, .failed:
            vm.retry()
            
        case .listening:
            vm.cancelListening()
            
        case .processing, .completed:
            break
        }
    }
}
