

import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
final class LocationLiveTesterVM: NSObject, ObservableObject {
    @Published var statusText: String = "—"
    @Published var coordText: String = "—"
    @Published var accuracyText: String = "—"
    @Published var speedText: String = "—"
    @Published var timestampText: String = "—"
    @Published var isUpdating: Bool = false

    private let locationService: LocationService

    init(locationService: LocationService) {
        self.locationService = locationService
        super.init()
        // 실시간 값 반영 (LocationService가 @Published location 가지고 있음)
        // 필요시 Combine로 바인딩해도 되고, 여기선 didSet에서 직접 읽어옴
    }

    func requestOnce() {
        Task {
            do {
                let loc = try await locationService.requestOneShotLocation()
                apply(loc)
            } catch {
                statusText = "❌ 1회 요청 실패: \(error.localizedDescription)"
            }
        }
    }

    func start() {
        Task {
            do {
                try await locationService.startContinuousUpdates(
                    distanceFilter: 20,
                    accuracy: kCLLocationAccuracyBest
                )
                isUpdating = true
                statusText = "▶️ 업데이트 시작"
            } catch {
                statusText = "❌ 시작 실패: \(error.localizedDescription)"
            }
        }
    }

    func stop() {
        locationService.stopContinuousUpdates()
        isUpdating = false
        statusText = "⏹️ 업데이트 중지"
    }

    // LocationService가 didUpdateLocations에서 최신값을 올려줌
    // 간단히 폴링 없이, 뷰에서 onReceive로 location 바인딩 받아도 됨
    func apply(_ loc: CLLocation) {
        coordText = String(format: "%.6f, %.6f",
                           loc.coordinate.latitude, loc.coordinate.longitude)
        accuracyText = String(format: "±%.1fm (H), ±%.1fm (V)",
                              loc.horizontalAccuracy, loc.verticalAccuracy)
        speedText = String(format: "%.2f m/s", max(0, loc.speed))
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        timestampText = df.string(from: loc.timestamp)
    }

    var locationPublisher: Published<CLLocation?>.Publisher {
        locationService.$location
    }
}
