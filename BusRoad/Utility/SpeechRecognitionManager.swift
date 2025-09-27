import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - 음성 인식 매니저
@MainActor
class SpeechRecognitionManager: ObservableObject {
    
    // MARK: - 퍼블리시 프로퍼티들
    @Published var isRecording = false      // 녹음 중인지 여부
    @Published var recognizedText = ""      // 인식된 텍스트
    @Published var isAvailable = false      // 음성 인식 사용 가능 여부
    @Published var errorMessage: String?    // 에러 메시지
    
    // MARK: - 프라이빗 프로퍼티들
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 침묵 감지를 위한 타이머
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 3.0 // 3초
    
    // MARK: - 초기화
    init() {
        checkAvailability()
    }
    
    // MARK: - 공개 메서드들
    
    /// 음성 인식 시작
    func startRecording() {
        guard !isRecording else { return }
        
        Task {
            do {
                try await requestPermissions()
                try startRecognition()
            } catch {
                handleError(error)
            }
        }
    }
    
    /// 음성 인식 중지
    func stopRecording() {
        guard isRecording else { return }

        // 1) 오디오 엔진/탭 정리
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // 2) 리퀘스트/태스크 종료
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // 3) 세션 비활성화 (다음 시작을 위한 깔끔한 상태)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // 4) 상태/타이머
        isRecording = false
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    /// 상태 초기화
    func reset() {
        stopRecording()
        recognizedText = ""
        errorMessage = nil
    }
}

// MARK: - 프라이빗 메서드들
private extension SpeechRecognitionManager {
    
    /// 사용 가능 여부 확인
    func checkAvailability() {
        isAvailable = speechRecognizer?.isAvailable ?? false
        
        speechRecognizer?.delegate = SpeechRecognizerDelegate { [weak self] isAvailable in
            Task { @MainActor in
                self?.isAvailable = isAvailable
            }
        }
    }
    
    /// 권한 요청
    func requestPermissions() async throws {
        // 마이크 권한 요청 (iOS 17+ 호환)
        let audioPermission: Bool
        
        if #available(iOS 17.0, *) {
            audioPermission = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            audioPermission = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        
        guard audioPermission else {
            throw SpeechError.audioPermissionDenied
        }
        
        // 음성 인식 권한 요청
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechPermission else {
            throw SpeechError.speechPermissionDenied
        }
    }
    
    /// 음성 인식 시작
    func startRecognition() throws {
        // 기존 태스크 정리
        recognitionTask?.cancel()
        recognitionTask = nil

        // 오디오 세션
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 요청
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // iOS 13+ : 검색 용도 힌트 (선택)
        if #available(iOS 13.0, *) { request.taskHint = .search }
        recognitionRequest = request

        // 입력 탭
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        isRecording = true
        recognizedText = ""
        errorMessage = nil

        startSilenceTimer()
    }
    
    /// 인식 결과 처리
    func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            handleError(error)
            return
        }
        
        if let result = result {
            recognizedText = result.bestTranscription.formattedString
            
            // 최종 결과가 나왔으면 타이머 재시작, 아니면 계속 진행
            if result.isFinal {
                stopRecording()
            } else {
                restartSilenceTimer()
            }
        }
    }
    
    /// 침묵 타이머 시작
    func startSilenceTimer() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopRecording()
            }
        }
    }
    
    /// 침묵 타이머 재시작
    func restartSilenceTimer() {
        silenceTimer?.invalidate()
        startSilenceTimer()
    }
    
    /// 에러 처리
    func handleError(_ error: Error) {
        stopRecording()
        
        if let speechError = error as? SpeechError {
            errorMessage = speechError.localizedDescription
        } else {
            errorMessage = "음성 인식 중 오류가 발생했습니다."
        }
    }
}

// MARK: - 음성 인식 에러 타입
enum SpeechError: LocalizedError {
    case audioPermissionDenied      // 마이크 권한 거부
    case speechPermissionDenied     // 음성 인식 권한 거부
    case recognitionRequestFailed   // 인식 요청 실패
    case recognitionFailed          // 인식 실패
    
    var errorDescription: String? {
        switch self {
        case .audioPermissionDenied:
            return "마이크 권한이 필요합니다."
        case .speechPermissionDenied:
            return "음성 인식 권한이 필요합니다."
        case .recognitionRequestFailed:
            return "음성 인식 요청을 생성할 수 없습니다."
        case .recognitionFailed:
            return "음성 인식에 실패했습니다."
        }
    }
}

// MARK: - 음성 인식기 델리게이트
private class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
    let onAvailabilityChanged: (Bool) -> Void
    
    init(onAvailabilityChanged: @escaping (Bool) -> Void) {
        self.onAvailabilityChanged = onAvailabilityChanged
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        onAvailabilityChanged(available)
    }
}
