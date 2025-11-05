import Combine
import SwiftUI

@MainActor
final class BeforeRideViewModel: ObservableObject {
    @Published var journey: Journey?
    @Published var index: Int?
    @Published var isArrivingSoon: Bool = false
    @Published var hasPassed: Bool = false
    @Published var nearestBusInfo: (busNo: String, arrivalText: String)?
    @Published var lastPassedBusNo: String? = nil

    private var manager: JourneyManager
    private var cancellables = Set<AnyCancellable>()

    init(manager: JourneyManager = .shared) {
        self.manager = manager
        manager.$selectedJourney.assign(to: &$journey)
        manager.$journeyIndex.assign(to: &$index)
    }

    // MARK: - 실시간 루프 시작 (Task는 매니저가 관리)
    func startRefreshing(for route: BusRouteNode) {
        ArrivalInfoManager.shared.startAutoRefresh(for: route)
        Task { await updateOnce(for: route) }
    }

    // MARK: - 루프 중단
    func stopRefreshing() {
        ArrivalInfoManager.shared.stopAutoRefresh()
    }

    // MARK: - 1회 업데이트 (즉시 표시)
    private func updateOnce(for route: BusRouteNode) async {
        let result = await ArrivalInfoManager.shared.refreshNearestBusArrival(for: route)
        
        if result.didPass {
            hasPassed = true
            // 매니저에서 전달된 지나간 버스 번호 사용
            if let passed = result.passedBus {
                lastPassedBusNo = cleanBusNumber(passed.routeno)
            }
            print("[BeforeRideViewModel] 지나감 감지됨 (\(lastPassedBusNo ?? "-"))")
        }

        if let item = result.item {
            updateUI(with: item)
        }
    }


    // MARK: - UI 업데이트 로직
    private func updateUI(with item: BusArrivalItem) {
        let minutes = item.arrtime / 60
        let text = minutes < 1 ? "곧 도착" : "\(minutes)분 후"
        isArrivingSoon = minutes < 1
        nearestBusInfo = (busNo: cleanBusNumber(item.routeno), arrivalText: text)
    }

    // MARK: - 버스번호 클린업
    private func cleanBusNumber(_ busNo: String) -> String {
        var result = busNo
        let pattern = #"\([^()]*\)"#
        while let _ = result.range(of: pattern, options: .regularExpression) {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        if let lastChar = result.last, lastChar.isNumber {
            result += "번"
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
