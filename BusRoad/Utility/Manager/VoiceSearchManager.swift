import Combine

@MainActor
class VoiceSearchManager: ObservableObject {
    static let shared = VoiceSearchManager()
    
    @Published var isPresented: Bool = false
    var onCompleted: ((String) -> Void)?
    
    private init() {}
    
    func present(onCompleted: @escaping (String) -> Void) {
        self.onCompleted = onCompleted
        self.isPresented = true
    }
    
    func dismiss() {
        self.isPresented = false
        self.onCompleted = nil
    }
}
