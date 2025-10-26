import Foundation

struct KakaoKeywordResponse: Decodable {
    let documents: [KakaoPlace]
    let meta: KakaoMeta
}

struct KakaoMeta: Decodable {
    let totalCount: Int
    let isEnd: Bool
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case isEnd = "is_end"
    }
}


struct KakaoPlace: Identifiable, Hashable, Decodable {
    let id: String
    let placeName: String
    let addressName: String
    let roadAddressName: String
    let x: String
    let y: String
    let distance: String?
    
    enum CodingKeys: String, CodingKey {
        case id, x, y, distance
        case placeName = "place_name"
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
    }
    
    // 1. 도로명 우선, 없으면 지번 주소
     var displayAddress: String {
         roadAddressName.isEmpty ? addressName : roadAddressName
     }
     
     // 2. 좌표 변환 (String -> Double)
     var longitude: Double? {
         Double(x)
     }
     var latitude: Double? {
         Double(y)
     }
     
     // 3. 거리 표시용
     var distanceInMeters: Double? {
         distance.flatMap { Double($0) }
     }
}


extension KakaoPlace {
    func toSummary() -> PlaceSummary? {
        
        guard let lat = latitude, let lon = longitude else {
            return nil
        }
        
        return PlaceSummary(
            name: placeName,
            address: displayAddress,
            latitude: lat,
            longitude: lon
        )
    }
}


