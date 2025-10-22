import Combine
import SwiftUI
import CoreLocation

@MainActor
final class OnRideViewModel: ObservableObject {
    // UI 상태
    @Published var stopName: String = ""
    @Published var isNearAlight: Bool = false
    @Published var canAlight: Bool = false
    
    // 거리 & 근접 상태
    @Published private(set) var lastDistanceMeters: CLLocationDistance?
    @Published private(set) var progress: CGFloat = 0
    
    // 어떤 버스 구간을 감시할지 (환승 고려용)
    @Published var busLegIndex: Int = 0 {
        didSet {
            attachSelectedJourney(busLegIndex: busLegIndex)
        }
    }
        
    // 의존성
    private let locationService: LocationService
    private let journeyManager: JourneyManager
    private let proximity: AlightProximityManager
    
    private var bag = Set<AnyCancellable>()
    
    // 거리
    private var initialDistance: CLLocationDistance?           // 거리
    private var recentDistances: [CLLocationDistance] = []     // GPS 튀는것 방지를 위한 최근 샘플
    private let smoothCount: Int = 5                           // 최근 N개 평균
    private var maxProgress: CGFloat = 0                       // 뒤로가기 금지
    
    // 기본 생성자
    init(locationService: LocationService,
         journeyManager: JourneyManager,
         proximity: AlightProximityManager) {
        self.locationService = locationService
        self.journeyManager = journeyManager
        self.proximity = proximity
    }
    
    // convenience init
    convenience init() {
        let locationService = LocationService()
        let journeyManager  = JourneyManager.shared
        let proximity       = AlightProximityManager(locationService: locationService,
                                                     journeyManager: journeyManager)
        self.init(locationService: locationService,
                  journeyManager: journeyManager,
                  proximity: proximity)
    }
}

// MARK: - 설정/시작/중지
extension OnRideViewModel {
    
    /// 선택 여정에서 하차 정류장 이름 세팅 + 근접 감시 대상/반경 지정
    func attachSelectedJourney(busLegIndex: Int) {
        guard let journey = journeyManager.selectedJourney else {
            print("⚠️ 선택된 여정이 없습니다.")
            return
        }
        
        // 하차 정류장 이름
        if let alight = journey.alightStop(ofBusLeg: busLegIndex) {
            self.stopName = alight.name
        }
        
        
        // 근접 감시 설정 + 콜백
        proximity.configure(busLegIndex: busLegIndex)
        proximity.onEnterRadius = { [weak self] _, _ in
            self?.isNearAlight = true
            self?.canAlight = true
            let generator = UINotificationFeedbackGenerator()

            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + (1.0 * Double(i))) {
                    generator.notificationOccurred(.success)
                }
            }
        }
        proximity.onExitRadius  = { [weak self] _, _ in self?.isNearAlight = false }
        
        initialDistance = nil
        recentDistances.removeAll()
        maxProgress = 0
        progress = 0
    }
    
    /// 감시 시작 (외부에서 busLegIndex를 정했으면 그 값을 사용)
    func start() {
        // selectedJourney가 있고 busLegIndex가 유효하다는 전제하에 구성
        attachSelectedJourney(busLegIndex: busLegIndex)
        
        // 거리 스트림 구독 → progress 갱신
        bag.removeAll()
        
        // 상태 초기화
        initialDistance = nil
        recentDistances.removeAll()
        maxProgress = 0
        progress = 0
        canAlight = false
        
        proximity.$lastDistance
            .sink { [weak self] d in
                guard let self, let d else { return }
                
                // 최초 업데이트에서 초기 거리 저장
                if self.initialDistance == nil { self.initialDistance = d }
                
                // 최근 N개 이동 평균 (gps 튀는것 최대한 보정)
                self.recentDistances.append(d)
                if self.recentDistances.count > self.smoothCount {
                    self.recentDistances.removeFirst()
                }
                let smoothed = self.recentDistances.reduce(0, +) / Double(self.recentDistances.count)
                
                // 화면용 표시 거리 업데이트
                self.lastDistanceMeters = smoothed
                
                // 진행률: 1 - (현재/초기)
                if let total = self.initialDistance, total > 0 {
                    let ratio = 1.0 - (smoothed / total)
                    let clamped = CGFloat(min(max(ratio, 0), 1))
                    // 후퇴 금지: 항상 최대값 유지
                    self.maxProgress = max(self.maxProgress, clamped)
                    self.progress = self.maxProgress
                } else {
                    self.progress = 0
                }
            }
            .store(in: &bag)
        

Task {
    do { try await locationService.startContinuousUpdates() }
    catch { print("위치 업데이트 시작 실패: \(error)") }
}

        
        proximity.start()
    }
    
    func stop() {
        bag.removeAll()
        proximity.stop()
        locationService.stopContinuousUpdates()
        initialDistance = nil
        recentDistances.removeAll()
        maxProgress = 0
        progress = 0
        canAlight = false
        
    }
}
