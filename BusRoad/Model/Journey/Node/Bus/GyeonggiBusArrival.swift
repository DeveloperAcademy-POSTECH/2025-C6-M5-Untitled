import Foundation

// MARK: - 경기도 버스 도착정보 응답

struct GyeonggiArrivalResponse: Decodable {
    let msgHeader: GyeonggiMsgHeader
    let msgBody: GyeonggiArrivalBody?
}

struct GyeonggiMsgHeader: Decodable {
    let queryTime: String?
    let resultCode: Int
    let resultMessage: String
}

struct GyeonggiArrivalBody: Decodable {
    let busArrivalList: GyeonggiArrivalList?
}

struct GyeonggiArrivalList: Decodable {
    let items: [GyeonggiArrivalItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // 배열인 경우
        if let itemsArray = try? container.decode([GyeonggiArrivalItem].self) {
            self.items = itemsArray
            return
        }

        // 단일 객체인 경우
        if let singleItem = try? container.decode(GyeonggiArrivalItem.self) {
            self.items = [singleItem]
            return
        }

        // 빈 경우
        self.items = []
    }
}

struct GyeonggiArrivalItem: Decodable {
    let routeId: Int
    let routeName: String?
    let routeTypeCd: Int?
    let stationId: Int
    let staOrder: Int

    // 첫 번째 버스
    let predictTime1: Int?
    let predictTimeSec1: Int?
    let locationNo1: Int?
    let plateNo1: String?
    let lowPlate1: Int?
    let crowded1: Int?
    let remainSeatCnt1: Int?

    // 두 번째 버스
    let predictTime2: Int?
    let predictTimeSec2: Int?
    let locationNo2: Int?
    let plateNo2: String?
    let lowPlate2: Int?
    let crowded2: Int?
    let remainSeatCnt2: Int?

    let flag: String?
}

// MARK: - BusArrivalItem 변환

extension GyeonggiArrivalItem {

    /// 첫 번째 버스 도착정보를 BusArrivalItem으로 변환
    func toBusArrivalItem1() -> BusArrivalItem? {
        // predictTimeSec1 또는 predictTime1 * 60 사용
        let arrivalSeconds: Int
        if let sec = predictTimeSec1, sec > 0 {
            arrivalSeconds = sec
        } else if let min = predictTime1, min > 0 {
            arrivalSeconds = min * 60
        } else {
            return nil
        }

        let vehicleType = lowPlateToVehicleType(lowPlate1)

        return BusArrivalItem(
            routeno: routeName ?? String(routeId),
            routeid: String(routeId),
            arrtime: arrivalSeconds,
            vehicletp: vehicleType,
            arrprevstationcnt: locationNo1 ?? 0
        )
    }

    /// 두 번째 버스 도착정보를 BusArrivalItem으로 변환
    func toBusArrivalItem2() -> BusArrivalItem? {
        let arrivalSeconds: Int
        if let sec = predictTimeSec2, sec > 0 {
            arrivalSeconds = sec
        } else if let min = predictTime2, min > 0 {
            arrivalSeconds = min * 60
        } else {
            return nil
        }

        let vehicleType = lowPlateToVehicleType(lowPlate2)

        return BusArrivalItem(
            routeno: routeName ?? String(routeId),
            routeid: String(routeId),
            arrtime: arrivalSeconds,
            vehicletp: vehicleType,
            arrprevstationcnt: locationNo2 ?? 0
        )
    }

    /// lowPlate 값을 차량 타입 문자열로 변환
    private func lowPlateToVehicleType(_ lowPlate: Int?) -> String {
        switch lowPlate {
        case 0: return "일반"
        case 1: return "저상"
        case 2: return "2층"
        default: return "일반"
        }
    }
}
