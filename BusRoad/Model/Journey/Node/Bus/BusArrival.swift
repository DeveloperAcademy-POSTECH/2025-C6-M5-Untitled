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
        
        // 먼저 어떤 타입인지 확인
        if let itemsArray = try? container.decode([NodeIdItem].self, forKey: .item) {
            print("[NodeIdItems] 배열로 디코딩 성공: \(itemsArray.count)개")
            self.item = itemsArray
        } else if let singleItem = try? container.decode(NodeIdItem.self, forKey: .item) {
            // 단일 객체인 경우
            print("[NodeIdItems] 단일 객체로 디코딩 성공, 배열로 변환")
            self.item = [singleItem]
        } else {
            // 둘 다 안 되면 빈 배열
            print("[NodeIdItems] 디코딩 실패, 빈 배열 반환")
            self.item = []
        }
    }
}


struct NodeIdItem: Codable {
    let nodeid: String
    let nodenm: String
    let nodeno: Int
}

//MARK: - 버스 도착 정보 응답
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
        if let _ = try? container.decode(String.self, forKey: .item) {
            print("[BusArrivalItems] items가 빈 문자열입니다")
            self.item = []
            return
        }
        
        // 배열인 경우
        if let itemsArray = try? container.decode([BusArrivalItem].self, forKey: .item) {
            print("[BusArrivalItems] 배열로 디코딩 성공: \(itemsArray.count)개")
            self.item = itemsArray
        }
        // 단일 객체인 경우
        else if let singleItem = try? container.decode(BusArrivalItem.self, forKey: .item) {
            print("[BusArrivalItems] 단일 객체로 디코딩 성공, 배열로 변환")
            self.item = [singleItem]
        }
        // 그 외 오류
        else {
            print("[BusArrivalItems] 디코딩 실패, 빈 배열 반환")
            self.item = []
        }
    }
}

struct BusArrivalItem: Codable, Identifiable {
    var id = UUID()
    let routeno: Int
    let arrtime: Int
    let vehicletp: String?
    let arrprevstationcnt: Int
    
    enum CodingKeys: String, CodingKey {
        case routeno
        case arrtime
        case vehicletp
        case arrprevstationcnt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routeno = try container.decode(Int.self, forKey: .routeno)
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
