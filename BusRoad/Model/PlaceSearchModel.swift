import Foundation

struct NaverLocalResponse: Decodable {
    let items: [NaverLocalItem]
}

struct NaverLocalItem: Identifiable, Hashable, Decodable {
    var id: UUID
    
    let title: String?
    let category: String?
    let address: String?
    let roadAddress: String?
    let mapx: String?
    let mapy: String?
    
    enum CodingKeys: String, CodingKey {
        case title, category, address, roadAddress, mapx, mapy
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.category = try c.decodeIfPresent(String.self, forKey: .category)
        self.address = try c.decodeIfPresent(String.self, forKey: .address)
        self.roadAddress = try c.decodeIfPresent(String.self, forKey: .roadAddress)
        self.mapx = try c.decodeIfPresent(String.self, forKey: .mapx)
        self.mapy = try c.decodeIfPresent(String.self, forKey: .mapy)
        self.id = UUID()
    }
    
    // <b>태그 제거
    var plainTitle: String {
        (title ?? "")
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
    }
    
    // 도로명 우선 표시, 없으면 지번
    var displayAddress: String {
        if let road = roadAddress, !road.isEmpty { return road }
        return address ?? ""
    }
}
