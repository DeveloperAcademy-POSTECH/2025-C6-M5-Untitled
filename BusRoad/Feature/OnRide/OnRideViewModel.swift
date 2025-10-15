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
            attachSelectedJourney(busLegIndex: busLegIndex, enter: enterRadiusMeters, exit: enterRadiusMeters+40)
        }
    }
    
    // 노멀라이즈 기준
    private var enterRadiusMeters: CLLocationDistance = 150
    
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
        attachSelectedJourney(busLegIndex: busLegIndex, enter: 150, exit: 190)
        
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
        
//#if !DEBUG
Task {
    do { try await locationService.startContinuousUpdates() }
    catch { print("위치 업데이트 시작 실패: \(error)") }
}
//#endif
        
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



//#if DEBUG
//extension OnRideViewModel {
//    /// 🔥 가장 쉬운 풀-플로우 데모: 버스1 → 환승 → 버스2
//    /// 실제 GPS/권한 없이, UI/상태 전환(카드색/버튼/프로그레스/환승) 전부 확인 가능
//    func startFullTransferDemo() {
//        // 1) 여정 주입: [bus, walk, bus]
//        let leg1End = LocationInfo(name: "환승 정류장", latitude: 36.0348, longitude: 129.3340) // 1구간 하차 지점(타깃1)
//        let leg2End = LocationInfo(name: "최종 하차(포항역)", latitude: 36.07160518, longitude: 129.3419282) // 2구간 하차 지점(타깃2)
//
//        let leg1Start = LocationInfo(name: "출발(대충 멀리)", latitude: leg1End.latitude + 0.006, longitude: leg1End.longitude) // 약 600~700m 북쪽
//        let leg2Start = LocationInfo(name: "환승 후 승차", latitude: leg2End.latitude + 0.0035, longitude: leg2End.longitude)   // 약 350~400m 북쪽
//
//        let bus1 = BusRouteNode(start: leg1Start, end: leg1End, busNo: "가짜100", busId: 100, stations: [], travelTime: 12)
//        let walk = WalkRouteNode(start: leg1End, end: leg2Start, travelTime: 3) // 실제 좌표는 비슷하게
//        let bus2 = BusRouteNode(start: leg2Start, end: leg2End, busNo: "가짜200", busId: 200, stations: [], travelTime: 18)
//
//        let journey = Journey(totalTime: 33, nodes: [.bus(bus1), .walk(walk), .bus(bus2)])
//        journeyManager.selectedJourney = journey
//        journeyManager.journeyIndex = 0  // 현재 노드: bus1
//        busLegIndex = 0                  // 현재 버스 구간: 0
//
//        // 2) 근접 감시/구독 준비
//        start() // attachSelectedJourney + proximity.start + 거리 sink 세팅
//
//        // 3) 좌표 생성: “타깃을 향해 내려오는 직선 경로” (위도만 살짝씩 줄이는 간단한 방식)
//        //    위도 0.001° ≈ 111m 라고 생각하면 됩니다.
//        func approachPath(to target: LocationInfo, startLatOffset: Double, steps: Int) -> [CLLocationCoordinate2D] {
//            let startLat = target.latitude + startLatOffset
//            let lon = target.longitude
//            let d = startLatOffset / Double(steps - 1)
//            return (0..<steps).map { i in
//                .init(latitude: startLat - Double(i) * d, longitude: lon)
//            }
//        }
//
//        let leg1Path = approachPath(to: leg1End, startLatOffset: 0.006, steps: 25)   // 대략 600~700m → 0m
//        let leg2Path = approachPath(to: leg2End, startLatOffset: 0.0035, steps: 20)  // 대략 350~400m → 0m
//
//        // 4) 실제 스트림처럼 LocationService로 좌표를 흘려보냄
//        locationService.playOnce(coordinates: leg1Path, interval: 0.35) { [weak self] in
//            guard let self else { return }
//
//            // ▶️ 환승 처리: 여정 인덱스를 도보 → 다음 버스 구간으로 이동
//            self.journeyManager.journeyIndex = 1 // 현재 노드: walk
//            self.journeyManager.journeyIndex = 2 // 현재 노드: bus2
//
//            // 현재 버스 구간 계산 → ViewModel에게 전달
//            if let j = self.journeyManager.selectedJourney,
//               let nextLeg = j.busLegIndex(forNodeIndex: 2) {
//                self.busLegIndex = nextLeg // didSet에서 attachSelectedJourney 호출 → 타깃/상태 리셋
//            }
//
//            // 2구간 재생
//            self.locationService.playOnce(coordinates: leg2Path, interval: 0.35) {
//                print("✅ 풀-데모 완료(최종 하차 근접)")
//            }
//        }
//    }
//}
//#endif
