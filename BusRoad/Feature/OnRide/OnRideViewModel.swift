import Combine
import SwiftUI
import CoreLocation

@MainActor
final class OnRideViewModel: ObservableObject {
    // UI 상태
    @Published var stopName: String = ""
    @Published var isNearAlight: Bool = false

    // 거리 & 근접 상태
    @Published private(set) var lastDistanceMeters: CLLocationDistance?

    // 어떤 버스 구간을 감시할지 (환승 고려용) 
    @Published var busLegIndex: Int = 0 {
        didSet {
            attachSelectedJourney(busLegIndex: busLegIndex, enter: enterRadiusMeters, exit: enterRadiusMeters+40)
        }
    }
    
    // 노멀라이즈 기준
    private var enterRadiusMeters: CLLocationDistance = 150
    private var capMeters: CLLocationDistance { max(enterRadiusMeters * 2, 300) }

    // 의존성 (B안)
    private let locationService: LocationService
    private let journeyManager: JourneyManager
    private let proximity: AlightProximityManager

    private var bag = Set<AnyCancellable>()

    // 거리 비율 기반 프로그레스 (0~1)
    var progress: CGFloat {
        guard let d = lastDistanceMeters else { return 0 }
        let clamped = min(max(d, 0), capMeters)
        let ratio = 1.0 - (clamped / capMeters)   // 멀수록 0, 가까울수록 1
        return CGFloat(ratio)
    }

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
    func attachSelectedJourney(busLegIndex: Int, enter: CLLocationDistance = 150, exit: CLLocationDistance = 190) {
        guard let journey = journeyManager.selectedJourney else {
            print("⚠️ 선택된 여정이 없습니다.")
            return
        }

        // 하차 정류장 이름
        if let alight = journey.alightStop(ofBusLeg: busLegIndex) {
            self.stopName = alight.name
        }

        // progress 정규화 기준 저장
        self.enterRadiusMeters = enter

        // 근접 감시 설정 + 콜백
        proximity.configure(busLegIndex: busLegIndex, enter: enter, exit: exit)
        proximity.onEnterRadius = { [weak self] _, _ in self?.isNearAlight = true }
        proximity.onExitRadius  = { [weak self] _, _ in self?.isNearAlight = false }
    }

    /// 감시 시작 (외부에서 busLegIndex를 정했으면 그 값을 사용)
    func start() {
        // selectedJourney가 있고 busLegIndex가 유효하다는 전제하에 구성
        attachSelectedJourney(busLegIndex: busLegIndex, enter: 150, exit: 190)

        // 거리 스트림 구독 → progress 갱신
        bag.removeAll()
        proximity.$lastDistance
            .sink { [weak self] d in self?.lastDistanceMeters = d }
            .store(in: &bag)
        Task {
            do {
                try await locationService.startContinuousUpdates()
            } catch {
                print("위치 업데이트 시작 실패: \(error)")
            }
        }
        
        proximity.start()
    }

    func stop() {
        bag.removeAll()
        proximity.stop()
        locationService.stopContinuousUpdates()
    }
}
