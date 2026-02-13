//
//  GoogleLocalItem.swift
//  BusRoad
//
//  Created by 박난 on 1/30/26.
//

struct GoogleTextSearchResponse: Codable {
    let results: [GooglePlace]
    let status: String
}

struct GooglePlace: Codable, Identifiable {
    let placeId: String
    let name: String
    let formattedAddress: String?
    let geometry: GoogleGeometry
    let rating: Double?
    let types: [String]?
    
    var id: String { placeId }
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case geometry
        case rating
        case types
    }
}

struct GoogleGeometry: Codable {
    let location: GoogleLocation
}

struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}

extension GooglePlace {
    func toSummary() -> PlaceSummary? {
        PlaceSummary(
            name: name,
            address: formattedAddress ?? "",
            latitude: geometry.location.lat,
            longitude: geometry.location.lng
        )
    }
}
