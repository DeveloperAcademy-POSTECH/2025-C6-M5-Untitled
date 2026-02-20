import Foundation

class BusServiceFactory {

    // 경기도 cityCode 범위: 31010 ~ 31380
    private static let gyeonggiCityCodeRange = 31010...31380

    static func create(cityCode: Int) -> BusServiceType {
        if cityCode == 1000 {
            return SeoulBusService()
        } else if gyeonggiCityCodeRange.contains(cityCode) {
            return GyeonggiBusService()
        } else {
            return TagoBusService()
        }
    }

    /// 경기도 지역인지 확인
    static func isGyeonggi(cityCode: Int) -> Bool {
        return gyeonggiCityCodeRange.contains(cityCode)
    }
}

