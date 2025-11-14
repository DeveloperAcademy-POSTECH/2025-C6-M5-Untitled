import Combine
import SwiftUI

@MainActor
final class BeforeRideViewModel: ObservableObject {
    @Published var journey: Journey?
    @Published var index: Int?
    
    // Manager의 Published 값들을 그대로 observe
    @Published var nearestBusInfo: (busNo: String, arrivalText: String)?
    @Published var isArrivingSoon: Bool = false
    @Published var hasPassed: Bool = false
    @Published var lastPassedBusNo: String? = nil
    @Published var isReady: Bool = false

    private var manager: JourneyManager
    private var cancellables = Set<AnyCancellable>()
    private let arrivalManager: ArrivalInfoManager

    init(manager: JourneyManager = .shared, arrivalManager: ArrivalInfoManager = .shared) {
        self.manager = manager
        self.arrivalManager = arrivalManager
        
        manager.$selectedJourney.assign(to: &$journey)
        manager.$journeyIndex.assign(to: &$index)
        
        arrivalManager.$nearestBusInfo.assign(to: &$nearestBusInfo)
        arrivalManager.$isArrivingSoon.assign(to: &$isArrivingSoon)
        arrivalManager.$hasPassed.assign(to: &$hasPassed)
        arrivalManager.$lastPassedBusNo.assign(to: &$lastPassedBusNo)
    }

    // 데이터 준비 (도착 정보 로드 대기)
    func prepareData() async {
        guard let journey = journey,
              let index = index,
              case let .bus(busNode) = journey.nodes[index] else {
            isReady = true
            return
        }
        
        // 도착 정보 조회 시작
        startRefreshing(for: busNode)
        
        // 첫 도착 정보 대기 (최대 3초)
        var attempts = 0
        while nearestBusInfo == nil && attempts < 30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        // 약간의 딜레이 후 화면 표시
        try? await Task.sleep(nanoseconds: 200_000_000)
        isReady = true
    }

    // MARK: - 실시간 루프 시작 / 중단
    func startRefreshing(for route: BusRouteNode) {
        arrivalManager.startAutoRefresh(for: route)
    }

    func stopRefreshing() {
        arrivalManager.stopAutoRefresh()
    }
    
    func endManager() {
        arrivalManager.endManager()
        isReady = false
    }
    
    func acknowledgeMiss() {
        arrivalManager.acknowledgePassed()
        
        if let journey = journey,
           let index = index,
           case let .bus(busNode) = journey.nodes[index] {
            Task {
                await arrivalManager.forceRefresh(for: busNode)
            }
        }
    }
}
