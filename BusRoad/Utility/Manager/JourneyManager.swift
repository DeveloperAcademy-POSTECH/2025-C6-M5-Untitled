import CoreLocation
import Combine

final class JourneyManager: ObservableObject {
    // TODO: 변수 순서 컨벤션 맞춰서 조정하기
    @Published var origin: LocationInfo?
    @Published var destination: LocationInfo?
    var journeyList: [Journey]?

    static let shared = JourneyManager()    // singleton manager
    
    let locationService = LocationService()
    
    func setOrigin(_ origin: LocationInfo) {
        self.origin = origin
    }
    
    func setDestination(_ destination: LocationInfo) {
        self.destination = destination
    }
    
    func requestOrigin() {
        Task { @MainActor in
            do {
                let loc = try await locationService.requestOneShotLocation()
                print("[DEBUG] 현재 위치 저장")
                self.setOrigin(
                    LocationInfo(
                        name: "현위치",
                        longitude: loc.coordinate.longitude,
                        latitude:  loc.coordinate.latitude
                    )
                )
            } catch {
                print("[DEBUG] 위치 요청 실패: \(error.localizedDescription)")
            }
        }
    }
}
