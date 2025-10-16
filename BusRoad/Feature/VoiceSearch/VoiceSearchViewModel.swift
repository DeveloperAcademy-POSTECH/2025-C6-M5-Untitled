import Combine
import Foundation

enum VoiceSearchState { case ready, listening, processing, completed, failed }

@MainActor
final class VoiceSearchViewModel: ObservableObject {
    @Published var state: VoiceSearchState = .ready
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    
    private let searchManager = SearchManager.shared
    private let speechManager = SpeechRecognitionManager()
    private var cancellables = Set<AnyCancellable>()
    private var lastTranscript: String = ""
    private var isSearchCompleted = false
    
    var onSearchCompleted: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    
    init() { setupSpeechManager() }
    
    // MARK: - 공개 메서드들
    
    /// 음성 인식 시작
    func startListening() {
        guard speechManager.isAvailable else {
            handleError("음성 인식을 사용할 수 없습니다.")
            return
        }
        isSearchCompleted = false
        
        
        state = .listening
        errorMessage = nil
        recognizedText = ""
        
        speechManager.startRecording()
    }
    
    /// 음성 인식 중지
    func stopListening() {
        speechManager.stopRecording()
        if state == .listening {
            state = .ready
        }
    }
    
    /// 재시도
    func retry() {
        isSearchCompleted = false
        
        speechManager.reset()
        startListening()
    }
    
    /// 화면 닫기
    func dismiss() {
        speechManager.stopRecording()
        isSearchCompleted = false
        
        onDismiss?()
    }
    
    /// 뷰가 나타날 때 자동 시작
    func onAppear() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            startListening()
        }
    }
    
    
    /// 음성 인식 중단 (사용자가 직접 중단)
    func cancelListening() {
        
        speechManager.stopRecording()
        
        recognizedText = ""
        lastTranscript = ""
        
        state = .ready
        
        errorMessage = nil
    }
    
    
    // MARK: - 프라이빗 메서드들
    private func setupSpeechManager() {
        // 녹음 상태
        speechManager.$isRecording
            .sink { [weak self] isRecording in
                guard let self else { return }
                if !isRecording && self.state == .listening { self.state = .processing }
            }
            .store(in: &cancellables)
        
        // 인식 텍스트
        speechManager.$recognizedText
            .sink { [weak self] text in
                guard let self else { return }
                self.recognizedText = text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.lastTranscript = text
                }
            }
            .store(in: &cancellables)
        
        // 에러
        speechManager.$errorMessage
            .sink { [weak self] err in
                if let e = err { self?.handleError(e) }
            }
            .store(in: &cancellables)
        
        // 완료 판정
        speechManager.$isRecording
            .combineLatest(speechManager.$recognizedText)
            .sink { [weak self] isRecording, _ in
                guard let self else { return }
                guard !isRecording, self.state == .processing else { return }
                
                let now = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !now.isEmpty { self.completeVoiceSearch(with: now); return }
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard self.state == .processing else { return }
                    let later = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !later.isEmpty { self.completeVoiceSearch(with: later) }
                    else { self.handleError("음성을 인식하지 못했습니다.") }
                }
            }
            .store(in: &cancellables)
    }
    
    private func completeVoiceSearch(with text: String) {
        isSearchCompleted = true
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return handleError("음성을 인식하지 못했습니다.") }
        
        state = .completed
        recognizedText = trimmed
        
        Task { @MainActor in
            await searchManager.searchWithVoiceResult(trimmed)
            onSearchCompleted?(trimmed)
        }
    }
    
    private func handleError(_ message: String) {
        guard !isSearchCompleted else { return }
        state = .failed
        errorMessage = message
    }
}
// MARK: - 편의 확장
extension VoiceSearchViewModel {
    
    /// 가운데 표시할 메시지
    var centerMessage: String {
        switch state {
        case .ready:
            return "원하는 장소를 말해보세요."
        case .listening:
            // 듣는 중에도 실시간으로 인식된 텍스트 표시
            return recognizedText.isEmpty ? "원하는 장소를 말해보세요." : recognizedText
        case .processing:
            return recognizedText.isEmpty ? "" : recognizedText
        case .completed:
            return recognizedText
        case .failed:
            return "마이크를 눌러서 다시 말해주세요."
        }
    }
    
    /// 파동 애니메이션 표시 여부
    var showWaveAnimation: Bool {
        return state == .listening
    }
    
    /// 마이크 버튼 활성화 여부
    var isMicButtonEnabled: Bool {
        return state == .ready || state == .failed || state == .listening
    }
}
