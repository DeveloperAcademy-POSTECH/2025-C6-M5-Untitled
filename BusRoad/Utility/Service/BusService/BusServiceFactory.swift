import Foundation

class BusServiceFactory {
    static func create(cityCode: Int) -> BusServiceType {
        if cityCode == 1000 {
            return SeoulBusService()
        } else {
            return TagoBusService()
        }
    }
}

