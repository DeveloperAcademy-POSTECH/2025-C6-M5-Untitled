import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - 음성 인식 매니저
@MainActor
final class SpeechRecognitionManager: ObservableObject {

    // MARK: Published
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var isAvailable = false
    @Published var errorMessage: String?

    // MARK: Private
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var speechDelegate: SpeechRecognizerDelegate?

    private var silenceTask: Task<Void, Never>?
    var silenceThreshold: TimeInterval = 3.0

    // MARK: Init
    init() { checkAvailability() }

    // MARK: Public API
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

    func stopRecording() {
        guard isRecording else { return }

        // 인식/오디오 종료
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        // 침묵 태스크 취소
        silenceTask?.cancel()
        silenceTask = nil
    }

    func reset() {
        stopRecording()
        recognizedText = ""
        errorMessage = nil
    }
}

// MARK: - Private
private extension SpeechRecognitionManager {

    func checkAvailability() {
        isAvailable = speechRecognizer?.isAvailable ?? false

        speechDelegate = SpeechRecognizerDelegate { [weak self] available in
            Task { @MainActor in self?.isAvailable = available }
        }
        speechRecognizer?.delegate = speechDelegate
    }

    func requestPermissions() async throws {
        // 마이크
        let micOK: Bool = await withCheckedContinuation { cont in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        guard micOK else { throw SpeechError.audioPermissionDenied }

        // 음성 인식
        let speechOK: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { throw SpeechError.speechPermissionDenied }
    }

    func startRecognition() throws {
        // 기존 작업 정리
        recognitionTask?.cancel(); recognitionTask = nil

        // 오디오 세션
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // 요청
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // 입력 탭
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // 오디오 버퍼는 오디오 스레드에서 들어오므로 self는 약하게
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // 인식 태스크
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.handleRecognitionResult(result: result, error: error)
            }
        }

        isRecording = true
        recognizedText = ""
        errorMessage = nil

        // 침묵 감지 시작
        restartSilenceTask()
    }

    func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error { handleError(error); return }

        if let result {
            recognizedText = result.bestTranscription.formattedString
            if result.isFinal {
                stopRecording()        // 최종 결과면 종료
            } else {
                restartSilenceTask()   // 말이 계속 들어오면 침묵 타이머 리셋
            }
        }
    }

    // MARK: Silence using Task (Swift 6-safe)
    func restartSilenceTask() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(silenceThreshold * 1_000_000_000))
            self.stopRecording()
        }
    }

    func handleError(_ error: Error) {
        stopRecording()
        if let e = error as? SpeechError {
            errorMessage = e.localizedDescription
        } else {
            errorMessage = "음성 인식 중 오류가 발생했습니다."
        }
    }
}

// MARK: - 에러
enum SpeechError: LocalizedError {
    case audioPermissionDenied
    case speechPermissionDenied
    case recognitionRequestFailed
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .audioPermissionDenied:   return "마이크 권한이 필요합니다."
        case .speechPermissionDenied:  return "음성 인식 권한이 필요합니다."
        case .recognitionRequestFailed:return "음성 인식 요청을 생성할 수 없습니다."
        case .recognitionFailed:       return "음성 인식에 실패했습니다."
        }
    }
}

// MARK: - Delegate
private final class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
    let onAvailabilityChanged: (Bool) -> Void
    init(onAvailabilityChanged: @escaping (Bool) -> Void) { self.onAvailabilityChanged = onAvailabilityChanged }
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        onAvailabilityChanged(available)
    }
}
