import Foundation


struct KakaoAddressResponse: Decodable {
    let documents: [KakaoAddressDocument]
    let meta: KakaoMeta
}

struct KakaoAddressDocument: Identifiable, Hashable, Decodable {
    let addressName: String
    let x: String
    let y: String
    let roadAddress: RoadAddressDetail?
    let address: AddressDetail?
    
    var id: String { "\(x),\(y)" }
    
    enum CodingKeys: String, CodingKey {
        case addressName = "address_name"
        case x, y
        case roadAddress = "road_address"
        case address
    }
    
    // 도로명 우선 표시
    var displayAddress: String {
        roadAddress?.addressName ?? address?.addressName ?? addressName
    }
    
    // 건물명
    var buildingName: String? {
        roadAddress?.buildingName
    }
    
    var longitude: Double? { Double(x) }
    var latitude: Double? { Double(y) }
}

struct RoadAddressDetail: Hashable, Decodable {
    let addressName: String
    let buildingName: String
    
    enum CodingKeys: String, CodingKey {
        case addressName = "address_name"
        case buildingName = "building_name"
    }
}

struct AddressDetail: Hashable, Decodable {
    let addressName: String
    
    enum CodingKeys: String, CodingKey {
        case addressName = "address_name"
    }
}
extension KakaoAddressDocument {
    func toSummary() -> PlaceSummary? {
        guard let lat = latitude, let lon = longitude else {
            return nil
        }
        
        let name: String
        if let buildingName = buildingName, !buildingName.isEmpty {
            name = buildingName
        } else {
            name = displayAddress
        }
        
        return PlaceSummary(
            name: name,
            address: displayAddress,
            latitude: lat,
            longitude: lon
        )
    }
}
