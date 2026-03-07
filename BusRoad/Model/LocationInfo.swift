//
//  LocalInfo.swift
//  BusRoad
//
//  Created by 박난 on 10/4/25.
//

import CoreLocation

struct LocationInfo: Equatable, Hashable {
    var name: String
    var englishName: String?
    var latitude: Double
    var longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension LocationInfo {
    var asCLLocation: CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
}
