import Foundation
import CoreLocation
import Combine

/// 하차 정류장(선택된 여정의 N번째 버스구간 'end')에 대한 근접 감시 매니저
@MainActor
final class AlightProximityManager: ObservableObject {

    // MARK: - 공개 상태 (UI 디버깅 용도)
    @Published private(set) var lastDistance: CLLocationDistance?   // 마지막 계산 거리(m)
    @Published private(set) var isInsideRadius: Bool = false        // 반경 안/밖 상태

    // MARK: - 의존성
    private let locationService: LocationService
    private let journeyManager: JourneyManager

    // MARK: - 내부 상태
    private var cancellable: AnyCancellable?
    private var targetStop: LocationInfo?           // 감시 대상 정류장
    private var enterRadius: CLLocationDistance = 150
    private var exitRadius: CLLocationDistance = 190 // 반경(미터)
    private var currentLegIndex: Int = 0            // 감시 중인 버스구간 인덱스

    // 상태 전이 감지를 위한 이전 값 보관
    private var wasInside: Bool = false

    // MARK: - 콜백
    var onEnterRadius: ((LocationInfo, CLLocationDistance) -> Void)?
    var onExitRadius:  ((LocationInfo, CLLocationDistance) -> Void)?

    // MARK: - Init
    init(locationService: LocationService, journeyManager: JourneyManager) {
        self.locationService = locationService
        self.journeyManager = journeyManager
    }

    // MARK: - 설정/시작/중지
    
    /// 감시할 버스구간과 반경 설정 (시작은 `start()`에서)
    func configure(busLegIndex: Int, enter: CLLocationDistance = 150, exit: CLLocationDistance = 190) {
        self.currentLegIndex = busLegIndex
        self.enterRadius = enter
        self.exitRadius = max(exit, enter + 10)
        
        guard let journey = journeyManager.selectedJourney,
              let stop = journey.alightStop(ofBusLeg: busLegIndex) else {
            print("감시 대상 하차 정류장을 찾을 수 없습니다.")
            self.targetStop = nil
            return
        }
        self.targetStop = stop
    }

    /// 실시간 감시 시작
    func start() {
        // 대상 없으면 시도해도 의미 없음
        guard targetStop != nil else { return }


        cancellable?.cancel()
        cancellable = locationService.$location
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                self?.evaluate(current: loc)   // 매 위치 업데이트마다 거리 계산
            }
    }

    /// 감시 중지
    func stop() {
        cancellable?.cancel()
        cancellable = nil
        lastDistance = nil
        isInsideRadius = false
        wasInside = false
    }

    // MARK: - 거리 계산/상태 전이
    private func evaluate(current: CLLocation) {
        guard let target = targetStop else { return }
        let t = CLLocation(latitude: target.latitude, longitude: target.longitude)
        let d = current.distance(from: t)
        lastDistance = d

        let insideNow = isInsideRadius
            ? (d <= exitRadius)   // 안에 있을 땐 넉넉히 벗어났을 때만 false
            : (d <= enterRadius)  // 밖에 있을 땐 들어왔을 때만 true

        if insideNow != isInsideRadius {
            isInsideRadius = insideNow
            if insideNow { onEnterRadius?(target, d) } else { onExitRadius?(target, d) }
        }
    }
}

