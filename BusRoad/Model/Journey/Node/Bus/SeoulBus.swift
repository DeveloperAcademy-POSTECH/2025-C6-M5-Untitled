import Foundation

struct SeoulArrivalResponse: Decodable {
    let comMsgHeader: ComMsgHeader?
    let msgHeader: MsgHeader?
    let msgBody: SeoulArrivalBody?
}

struct ComMsgHeader: Decodable {
    let returnCode: String?
    let errMsg: String?
    let successYN: String?
    let responseTime: String?
    let requestMsgID: String?
    let responseMsgID: String?
}

struct MsgHeader: Decodable {
    let headerMsg: String?
    let headerCd: String?
    let itemCount: Int?

    // itemCount가 "0"처럼 String으로 올 수도 있어서 방어
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        headerMsg = try? c.decode(String.self, forKey: .headerMsg)
        headerCd  = try? c.decode(String.self, forKey: .headerCd)
        if let n = try? c.decode(Int.self, forKey: .itemCount) {
            itemCount = n
        } else if let s = try? c.decode(String.self, forKey: .itemCount), let n = Int(s) {
            itemCount = n
        } else {
            itemCount = nil
        }
    }
    enum CodingKeys: String, CodingKey { case headerMsg, headerCd, itemCount }
}

struct SeoulArrivalBody: Decodable {
    let itemList: [SeoulArrivalItem]?
}

struct SeoulArrivalItem: Decodable {
    let rtNm: String
    let busRouteId: String
    let arrmsg1: String
    let busType1: String?
    let arrmsg2: String
    let busType2: String?
}

