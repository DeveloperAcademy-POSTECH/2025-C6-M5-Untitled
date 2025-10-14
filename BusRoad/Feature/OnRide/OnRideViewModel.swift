import Combine
import SwiftUI


@MainActor
final class OnRideViewModel: ObservableObject {
    // TODO: 나중에 선택한 전체 경로 및 실시간 위치에서 받아와야함
    @Published var stopName: String = "포항 성모병원"
    @Published var totalStops: Int = 10
    @Published var remainingStops: Int = 1
    
    /// 정류장 목록 (API에서 받아오기)
    private var routeStops: [String] = []

    /// 남은 버스 정류장 계산
    var progress: CGFloat {
        guard totalStops > 0 else { return 0 }
        let completed = max(0, totalStops - remainingStops)
        return CGFloat(min(max(Double(completed) / Double(totalStops), 0), 1))
         }
    
    /// 실시간 위치 업데이트시 호출
    func update(with currentStopID: String) {
        guard let idx = routeStops.firstIndex(of: currentStopID) else { return }
        remainingStops = max(0, totalStops - (idx + 1))
        stopName = routeStops[min(idx + 1, totalStops - 1)]
    }
    
    /// 처음 노선 데이터를 받아왔을 때 호출 (배열저장용)
    func setRoute(_ stops: [String]) {
        routeStops = stops
        totalStops = stops.count
        remainingStops = stops.count
    }
}

