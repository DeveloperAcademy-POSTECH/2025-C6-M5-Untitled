import Foundation

// MARK: - nodeId 조회 응답
struct NodeIdResponse: Codable {
    let response: NodeIdResponseBody
}

struct NodeIdResponseBody: Codable {
    let header: ResponseHeader
    let body: NodeIdBody?
}

struct NodeIdBody: Codable {
    let items: NodeIdItems
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int
}

struct NodeIdItems: Codable {
    let item: [NodeIdItem]
    
    enum CodingKeys: String, CodingKey {
        case item
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let itemsArray = try? container.decode([NodeIdItem].self, forKey: .item) {
            self.item = itemsArray
        } else if let singleItem = try? container.decode(NodeIdItem.self, forKey: .item) {
            self.item = [singleItem]
        } else {
            self.item = []
        }
    }
}

struct NodeIdItem: Codable {
    let nodeid: String
    let nodenm: String
    let nodeno: Int
}

// MARK: - 버스 도착 정보 응답
struct BusArrivalResponse: Codable {
    let response: BusArrivalResponseBody
}

struct BusArrivalResponseBody: Codable {
    let header: ResponseHeader
    let body: BusArrivalBody?
}

struct BusArrivalBody: Codable {
    let items: BusArrivalItems?
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case items
        case numOfRows
        case pageNo
        case totalCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // items가 빈 문자열("")인 경우 처리
        if let _ = try? container.decode(String.self, forKey: .items) {
            print("[BusArrivalBody] items가 빈 문자열")
            self.items = nil
        } else {
            self.items = try? container.decode(BusArrivalItems.self, forKey: .items)
        }
        
        self.numOfRows = try container.decode(Int.self, forKey: .numOfRows)
        self.pageNo = try container.decode(Int.self, forKey: .pageNo)
        self.totalCount = try container.decode(Int.self, forKey: .totalCount)
    }
}

struct BusArrivalItems: Codable {
    let item: [BusArrivalItem]
    
    enum CodingKeys: String, CodingKey {
        case item
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 빈 문자열인 경우 처리 (버스가 없는 경우)
        if let emptyString = try? container.decode(String.self, forKey: .item) {
            self.item = []
            return
        }
        
        // 배열인 경우
        if let itemsArray = try? container.decode([BusArrivalItem].self, forKey: .item) {
            self.item = itemsArray
            return
        }
        
        // 단일 객체인 경우
        if let singleItem = try? container.decode(BusArrivalItem.self, forKey: .item) {
            print("[BusArrivalItems] 단일 객체로 디코딩 성공, 배열로 변환")
            self.item = [singleItem]
            return
        }
        
        // 그 외 오류
        print("[BusArrivalItems] 디코딩 실패, 빈 배열 반환")
        self.item = []
    }
}

struct BusArrivalItem: Codable, Identifiable {
    var id = UUID()
    let routeno: String
    let routeid: String
    let arrtime: Int
    let vehicletp: String?
    let arrprevstationcnt: Int
    
    enum CodingKeys: String, CodingKey {
        case routeno
        case routeid
        case arrtime
        case vehicletp
        case arrprevstationcnt
    }
    
    // 서울 서비스용
    init(routeno: String, routeid: String, arrtime: Int, vehicletp: String?, arrprevstationcnt: Int) {
        self.routeno = routeno
        self.routeid = routeid
        self.arrtime = arrtime
        self.vehicletp = vehicletp
        self.arrprevstationcnt = arrprevstationcnt
    }
    
    // TAGO 서비스용 (JSON 파싱할 때 씀)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let routenoString = try? container.decode(String.self, forKey: .routeno) {
            routeno = routenoString
        } else if let routenoInt = try? container.decode(Int.self, forKey: .routeno) {
            routeno = String(routenoInt)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .routeno, in: container, debugDescription: "routeno error")
        }
        
        routeid = try container.decode(String.self, forKey: .routeid)
        arrtime = try container.decode(Int.self, forKey: .arrtime)
        vehicletp = try? container.decode(String.self, forKey: .vehicletp)
        arrprevstationcnt = try container.decode(Int.self, forKey: .arrprevstationcnt)
    }
}

// MARK: - 공통 헤더
struct ResponseHeader: Codable {
    let resultCode: String
    let resultMsg: String
}

// MARK: - 경기도 버스 도착정보 응답

struct GyeonggiArrivalResponse: Decodable {
    let response: GyeonggiResponseBody
}

struct GyeonggiResponseBody: Decodable {
    let msgHeader: GyeonggiMsgHeader
    let msgBody: GyeonggiArrivalBody?
}

struct GyeonggiMsgHeader: Decodable {
    let queryTime: String?
    let resultCode: Int
    let resultMessage: String
}

struct GyeonggiArrivalBody: Decodable {
    let busArrivalList: [GyeonggiArrivalItem]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 배열인 경우
        if let itemsArray = try? container.decode([GyeonggiArrivalItem].self, forKey: .busArrivalList) {
            self.busArrivalList = itemsArray
            return
        }

        // 단일 객체인 경우
        if let singleItem = try? container.decode(GyeonggiArrivalItem.self, forKey: .busArrivalList) {
            self.busArrivalList = [singleItem]
            return
        }

        // 빈 경우
        self.busArrivalList = nil
    }

    enum CodingKeys: String, CodingKey {
        case busArrivalList
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

    enum CodingKeys: String, CodingKey {
        case routeId, routeName, routeTypeCd, stationId, staOrder
        case predictTime1, predictTimeSec1, locationNo1, plateNo1, lowPlate1, crowded1, remainSeatCnt1
        case predictTime2, predictTimeSec2, locationNo2, plateNo2, lowPlate2, crowded2, remainSeatCnt2
        case flag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        routeId = try container.decode(Int.self, forKey: .routeId)
        stationId = try container.decode(Int.self, forKey: .stationId)
        staOrder = try container.decode(Int.self, forKey: .staOrder)

        // String 또는 Int로 올 수 있는 필드들
        routeName = try? Self.decodeStringOrInt(container, forKey: .routeName)
        routeTypeCd = try? Self.decodeIntOrString(container, forKey: .routeTypeCd)

        predictTime1 = try? Self.decodeIntOrString(container, forKey: .predictTime1)
        predictTimeSec1 = try? Self.decodeIntOrString(container, forKey: .predictTimeSec1)
        locationNo1 = try? Self.decodeIntOrString(container, forKey: .locationNo1)
        plateNo1 = try? container.decode(String.self, forKey: .plateNo1)
        lowPlate1 = try? Self.decodeIntOrString(container, forKey: .lowPlate1)
        crowded1 = try? Self.decodeIntOrString(container, forKey: .crowded1)
        remainSeatCnt1 = try? Self.decodeIntOrString(container, forKey: .remainSeatCnt1)

        predictTime2 = try? Self.decodeIntOrString(container, forKey: .predictTime2)
        predictTimeSec2 = try? Self.decodeIntOrString(container, forKey: .predictTimeSec2)
        locationNo2 = try? Self.decodeIntOrString(container, forKey: .locationNo2)
        plateNo2 = try? container.decode(String.self, forKey: .plateNo2)
        lowPlate2 = try? Self.decodeIntOrString(container, forKey: .lowPlate2)
        crowded2 = try? Self.decodeIntOrString(container, forKey: .crowded2)
        remainSeatCnt2 = try? Self.decodeIntOrString(container, forKey: .remainSeatCnt2)

        flag = try? container.decode(String.self, forKey: .flag)
    }

    // Int 또는 빈 문자열 처리
    private static func decodeIntOrString(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decode(String.self, forKey: key), let intValue = Int(stringValue) {
            return intValue
        }
        return nil
    }

    // String 또는 Int를 String으로 변환
    private static func decodeStringOrInt(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return stringValue.isEmpty ? nil : stringValue
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return String(intValue)
        }
        return nil
    }
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
