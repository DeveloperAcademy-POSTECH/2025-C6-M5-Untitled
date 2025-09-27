import Foundation
import Combine

// MARK: - 음성 검색 상태
enum VoiceSearchState {
    case ready          // 준비 상태
    case listening      // 듣는 중 (파동 애니메이션)
    case processing     // 처리 중 (음성 → 텍스트 변환)
    case completed      // 완료 (검색 실행)
    case failed         // 실패
}

// MARK: - 음성 검색 뷰모델
@MainActor
final class VoiceSearchViewModel: ObservableObject {
    
    // MARK: - 퍼블리시 프로퍼티들
    @Published var state: VoiceSearchState = .ready
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    
    // MARK: - 의존성
    private let speechManager = SpeechRecognitionManager()
    private let textSearchVM: TextSearchViewModel
    private var cancellables = Set<AnyCancellable>()
    private var lastTranscript: String = ""
    private var isSearchCompleted = false

    
    // MARK: - 콜백
    var onSearchCompleted: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    
    // MARK: - 초기화
    init(textSearchVM: TextSearchViewModel) {
        self.textSearchVM = textSearchVM
        setupSpeechManager()
    }
    
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
}

// MARK: - 프라이빗 메서드들
private extension VoiceSearchViewModel {
    
    /// 음성 인식 매니저 설정
    func setupSpeechManager() {
        // 녹음 상태 감시
        speechManager.$isRecording
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                
                if !isRecording && self.state == .listening {
                    self.state = .processing
                }
            }
            .store(in: &cancellables)
        
        // 인식된 텍스트 업데이트
        speechManager.$recognizedText
            .sink { [weak self] text in
                guard let self = self else { return }
                self.recognizedText = text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.lastTranscript = text
                }
            }
            .store(in: &cancellables)
        
        // 에러 처리
        speechManager.$errorMessage
            .sink { [weak self] errorMessage in
                if let error = errorMessage {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)
        
        // 음성 인식 완료 처리
        speechManager.$isRecording
            .combineLatest(speechManager.$recognizedText)
            .sink { [weak self] isRecording, _ in
                guard let self = self else { return }

                guard !isRecording, self.state == .processing else { return }

                let finalNow = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalNow.isEmpty {
                    self.completeVoiceSearch(with: finalNow)
                    return
                }

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초

                    // 핵심: 이미 completed 상태라면 에러 처리 하지 않음
                    guard self.state == .processing else { return }
                    
                    let finalAfter = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !finalAfter.isEmpty {
                        self.completeVoiceSearch(with: finalAfter)
                        
                    } else {
                        self.handleError("음성을 인식하지 못했습니다.")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// 음성 검색 완료 처리
    /// 음성 검색 완료 처리
    func completeVoiceSearch(with text: String) {
        isSearchCompleted = true
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return handleError("음성을 인식하지 못했습니다.") }

        state = .completed
        recognizedText = trimmed

        Task { @MainActor in
            textSearchVM.query = trimmed
            await textSearchVM.search()
            
            // 검색이 완료되면 바로 이동 (결과 유무 상관없이)
            onSearchCompleted?(trimmed)
        }
    }
    
    /// 에러 처리
    func handleError(_ message: String) {
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
                return "원하는 장소를 말해보세요"
            case .listening:
                // 듣는 중에도 실시간으로 인식된 텍스트 표시
                return recognizedText.isEmpty ? "원하는 장소를 말해보세요" : recognizedText
            case .processing:
                return recognizedText.isEmpty ? "" : recognizedText
            case .completed:
                return recognizedText
            case .failed:
                return "마이크를 눌러서 다시 말해주세요"
            }
        }
    
    /// 파동 애니메이션 표시 여부
    var showWaveAnimation: Bool {
        return state == .listening
    }
    
    /// 마이크 버튼 활성화 여부
    var isMicButtonEnabled: Bool {
        return state == .ready || state == .failed
    }
}


