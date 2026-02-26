import Foundation

class BusServiceFactory {

    // 경기도 cityCode 범위 (공공데이터포털): 31010 ~ 31380
    private static let gyeonggiCityCodeRange = 31010...31380

    // 경기도 cityCode 범위 (ODsay API): 1001 ~ 1099 (1010 성남, 1020 수원 등)
    private static let odsayGyeonggiCityCodeRange = 1001...1099

    // 서울 구 단위 cityCode 범위: 1100 ~ 1199 (강남구 1168, 강북구 1130 등)
    private static let seoulDistrictCodeRange = 1100...1199

    static func create(cityCode: Int) -> BusServiceType {
        if cityCode == 1000 || seoulDistrictCodeRange.contains(cityCode) {
            return SeoulBusService()
        } else if gyeonggiCityCodeRange.contains(cityCode) || odsayGyeonggiCityCodeRange.contains(cityCode) {
            return GyeonggiBusService()
        } else {
            return TagoBusService()
        }
    }

    /// 경기도 지역인지 확인
    static func isGyeonggi(cityCode: Int) -> Bool {
        return gyeonggiCityCodeRange.contains(cityCode) || odsayGyeonggiCityCodeRange.contains(cityCode)
    }

    /// 서울 지역인지 확인 (1000 또는 구 단위 코드 11xx)
    static func isSeoul(cityCode: Int) -> Bool {
        return cityCode == 1000 || seoulDistrictCodeRange.contains(cityCode)
    }
}

