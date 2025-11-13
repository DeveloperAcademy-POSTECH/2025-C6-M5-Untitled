//
//  PlaceSummary.swift
//  BusRoad
//
//  Created by 박난 on 10/4/25.
//

import SwiftUI
import CoreLocation

//MARK: - 화면전달용 DTO
struct PlaceSummary: Hashable, Identifiable, Codable {
    var id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
