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
    @Published var didFetchOnce: Bool = false

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

    // MARK: - 실시간 루프 시작 / 중단
    func startRefreshing(for route: BusRouteNode) {
        arrivalManager.startAutoRefresh(for: route)
        didFetchOnce = true
    }

    func stopRefreshing() {
        arrivalManager.stopAutoRefresh()
    }
    
    func endManager() {
        arrivalManager.endManager()
    }
    
    func acknowledgeMiss() {
        arrivalManager.acknowledgePassed()
        
        if let journey = journey,
           let index = index,
           case let .bus(busNode) = journey.nodes[index] {
            Task {
                await arrivalManager.forceRefresh(for: busNode)
                didFetchOnce = false
            }
        }
    }
}
