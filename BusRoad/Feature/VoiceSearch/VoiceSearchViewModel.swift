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
    private var isCancelled = false
    
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
        isCancelled = false
        
        
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
        isCancelled = false
        speechManager.reset()
        startListening()
    }
    
    /// 화면 닫기
    func dismiss() {
        print("[DEBUG] dismiss 호출")
        cancelListening()
        onDismiss?()
    }
    
    /// 뷰가 나타날 때 자동 시작
    func onAppear() {
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            startListening()
        }
    }
    
    /// 음성 인식 중단 (사용자가 직접 중단)
    func cancelListening() {
        print("[DEBUG] cancelListening 시작")
        
        // 가장 먼저 취소 플래그 설정 (다른 어떤 코드보다 먼저!)
        isCancelled = true
        
        print("[DEBUG] isCancelled 설정: \(isCancelled)")
        
        searchManager.reset()
        print("[DEBUG] SearchManager 리셋 완료")
        
        // 녹음 중지
        speechManager.stopRecording()
        
        // 상태 초기화
        state = .ready
        recognizedText = ""
        lastTranscript = ""
        errorMessage = nil
        isSearchCompleted = false
        
        print("[DEBUG] cancelListening 완료")
    }
    
    /// 사용자가 버튼을 눌렀을 때 
    func handleMicButtonTap() {
        switch state {
        case .ready, .failed:
            retry()
            
        case .listening:
            cancelListening()
            
        case .processing, .completed:
            break
        }
    }
    
    // MARK: - 프라이빗 메서드들
    private func setupSpeechManager() {
        // 녹음 상태
        speechManager.$isRecording
            .sink { [weak self] isRecording in
                guard let self else { return }
                if !isRecording && self.state == .listening && !self.isCancelled {
                    self.state = .processing
                }
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
                guard !self.isCancelled else { return }
                
                let now = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !now.isEmpty { self.completeVoiceSearch(with: now); return }
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard self.state == .processing else { return }
                    guard !self.isCancelled else { return }
                    let later = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !later.isEmpty {
                        self.completeVoiceSearch(with: later)
                    } else { self.handleError("음성을 인식하지 못했습니다.") }
                }
            }
            .store(in: &cancellables)
    }
    
    private func completeVoiceSearch(with text: String) {
        print("[DEBUG] completeVoiceSearch 진입 - isCancelled: \(isCancelled)")
        
        guard !isCancelled else {
            print("[DEBUG] 취소됨 - 검색 안 함")
            return
        }
        guard !isSearchCompleted else {
            print("[DEBUG] 이미 완료/취소됨")
            return
        }
        
        isSearchCompleted = true
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return handleError("음성을 인식하지 못했습니다.") }
        
        print("[DEBUG] 검색 준비: \(trimmed)")
        
        Task { @MainActor in
            guard !self.isCancelled else {
                print("[DEBUG] Task 시작 시점 - 취소 감지, 검색 중단")
                return
            }
            
            self.state = .completed
            self.recognizedText = trimmed
            self.onSearchCompleted?(trimmed)
            
            print("[DEBUG] 검색 실행: \(trimmed)")
            await self.searchManager.searchWithVoiceResult(trimmed)
            
            guard !self.isCancelled else {
                print("[DEBUG] 콜백 실행 전 - 취소 감지")
                self.searchManager.reset()
                return
            }
        }
    }
    
    private func handleError(_ message: String) {
        guard !isSearchCompleted else { return }
        guard !isCancelled else { return }
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
        return state == .listening || state == .ready
    }
    
    /// 마이크 버튼 활성화 여부
    var isMicButtonEnabled: Bool {
        return state == .ready || state == .failed || state == .listening
    }
}
