import MapKit

final class JourneyManager {
    // TODO: 변수 순서 컨벤션 맞춰서 조정하기
    var origin: CLLocationCoordinate2D?
    var destination: CLLocationCoordinate2D?
    var journeyList: [Journey]?

    static let shared = JourneyManager()    // singleton manager
    
    func setOrigin(_ origin: CLLocationCoordinate2D) {
        self.origin = origin
    }
    
    func setDestination(_ destination: CLLocationCoordinate2D) {
        self.destination = destination
    }
    
}
