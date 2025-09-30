import Foundation

struct NaverLocalResponse: Decodable {
    let items: [NaverLocalItem]
}

struct NaverLocalItem: Identifiable, Hashable, Decodable {
    var id: UUID = UUID()
    
    let title: String?
    let address: String?
    let roadAddress: String?
    let mapx: String?
    let mapy: String?
    
    enum CodingKeys: String, CodingKey {
        case title, address, roadAddress, mapx, mapy
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
    
    // 좌표 변환
    var longitude: Double? {
        mapx.flatMap { Double($0) }.map { $0 / 1e7 }
    }
    var latitude: Double? {
        mapy.flatMap { Double($0) }.map { $0 / 1e7 }
    }
}

//MARK: - 화면전달용 DTO 
struct PlaceSummary: Hashable, Identifiable, Codable {
    var id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

extension NaverLocalItem {
    func toSummary() -> PlaceSummary? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return .init(name: plainTitle, address: displayAddress, latitude: lat, longitude: lon)
    }
}
