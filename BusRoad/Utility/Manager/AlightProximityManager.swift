import Foundation
import CoreLocation
import Combine

/// 하차 정류장(선택된 여정의 N번째 버스구간 'end')에 대한 근접 감시 매니저
@MainActor
final class AlightProximityManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var currentStationIndex: Int = 0 // 현재까지 지나간 정류장
    @Published private(set) var remainingStations: Int = 0 // 남은 정류장 개수
    @Published private(set) var lastDistance: CLLocationDistance? // 다음 정류장까지 거리
    @Published private(set) var canAlight: Bool = false // 내릴 수 있는지(2정류장 남았을때)
    @Published private(set) var progress: CGFloat = 0 // 진행률
    
    // MARK: - 의존성
    private let locationService: LocationService
    private let journeyManager: JourneyManager
    
    // MARK: - 내부 상태
    private var cancellable: AnyCancellable?
    private var stations: [BusStation] = []  // 모든 정류장 리스트
    private var hasEnteredRadius: Bool = false // 정류장 안에 들어갔는지
    private let detectionRadius: CLLocationDistance = 50  // 50m 반경을 기준으로
    
    // MARK: - 콜백
    var onStationPassed: ((Int, String) -> Void)?
    
    // MARK: - Init
    init(locationService: LocationService, journeyManager: JourneyManager) {
        self.locationService = locationService
        self.journeyManager = journeyManager
    }
    
    // MARK: - 설정/시작/중지
    
    /// 감시할 버스구간과  설정
    func configure(busLegIndex: Int) {
        guard let journey = journeyManager.selectedJourney,
              let busNode = journey.busSegments[safe: busLegIndex] else {
            print("[AlightProximityManager] 유효하지 않은 버스 구간입니다.")
            return
        }
        
        // 모든 정류장 저장
        self.stations = busNode.stations
        self.currentStationIndex = 0
        self.remainingStations = stations.count
        self.canAlight = false
        self.hasEnteredRadius = false
        self.progress = 0
    }
    
    /// 실시간 감시 시작
    func start() {
        // 정류장 리스트가 비어있으면 시작 안하기
        guard !stations.isEmpty else {
            print("[AlightProximityManager] 정류장 정보가 없습니다.")
            return
        }
        
        
        cancellable?.cancel()
        cancellable = locationService.$location
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                self?.checkStationProximity(currentLocation: loc)
            }
    }
    
    /// 감시 중지
    func stop() {
        cancellable?.cancel()
        cancellable = nil
        lastDistance = nil
        hasEnteredRadius = false
        currentStationIndex = 0
        remainingStations = 0
        canAlight = false
        progress = 0
    }
    
    // MARK: - 정류장 근접 확인
    private func checkStationProximity(currentLocation: CLLocation) {
        
        // 다음에 확인할 정류장 찾기
        let nextStationIndex = currentStationIndex
        
        // 남은 정류장 없으면 종료
        guard nextStationIndex < stations.count else {
            print("[AlightProximityManger] 모든 정류장을 지났습니다.")
            return
        }
        
        // 다음 정류장 좌표
        let nextStation = stations[nextStationIndex]
        let stationLocation = CLLocation(
            latitude: nextStation.latitude,
            longitude: nextStation.longitude
        )
        
        // 거리 계산 (미터 단위)
        let distance = currentLocation.distance(from: stationLocation)
        self.lastDistance = distance
        
        if distance <= detectionRadius {
            if !hasEnteredRadius {
                hasEnteredRadius = true
                stationPassed(index: nextStationIndex, name: nextStation.stationName)
            }
        } else {
            if hasEnteredRadius && nextStationIndex == currentStationIndex {
                hasEnteredRadius = false
            }
        }
    }
    
    private func stationPassed(index: Int, name: String) {
        print("[AlightProximityManager] 정류장 통과: [\(index)] \(name)")
        
        currentStationIndex = index + 1
        remainingStations = stations.count - currentStationIndex
        
        print("[AlightProximityManager] 남은 정류장: \(remainingStations)개")
        
        progress = CGFloat(currentStationIndex) / CGFloat(stations.count)
        
        if remainingStations == 2 {
            canAlight = true
            print("[AlightProximityManager]  내릴 준비 - 버튼 활성화!")
        }
        
        onStationPassed?(index, name)
        hasEnteredRadius = false
    }
}

// 배열에서 안전하게 값을 꺼내는 기능 추가
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

