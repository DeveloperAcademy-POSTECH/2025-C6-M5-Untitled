import AVFoundation
import Combine


final class VoiceAnnouncementManager: NSObject, ObservableObject {
    
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // 백그라운드에서도 소리 나오게 설정
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(
                .playback,  // 재생 모드
                mode: .spokenAudio,  // 음성 전용
                options: [.duckOthers, .mixWithOthers]  // 다른 소리 줄이기
            )
            try audioSession.setActive(true)
            print("[음성안내] 오디오 설정 완료!")
        } catch {
            print("[음성안내] 오디오 설정 실패: \(error)")
        }
    }
    
    // 음성으로 말하기
    func announce(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = 0.5  // 말하는 속도 (0.5)
        
        print("[음성안내] '\(message)'")
        synthesizer.speak(utterance)
    }
    
    // 2정류장 남음
    func announceTwoStations() {
        announce("하차하기까지 두정류장 남았습니다.")
    }
    
    // 1정류장 남음
    func announceOneStation() {
        announce("이번 정류장에서 내려야해요.하차벨을 눌러주세요")
    }
}


