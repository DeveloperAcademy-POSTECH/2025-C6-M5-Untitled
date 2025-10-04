//
//  LocalInfo.swift
//  BusRoad
//
//  Created by 박난 on 10/4/25.
//

import CoreLocation

struct LocationInfo: Equatable {
    var name: String
    var longitude: Double
    var latitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
