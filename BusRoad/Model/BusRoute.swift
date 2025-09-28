//
//  BusRoute.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import Foundation
struct BusRoute: Identifiable,Hashable {
    let id = UUID()
    let origin: String
    let destination: String
    let busNumbers: [String]
    let stationGroups: [[String]]
    let totalTime: Int
    let estimatedArrivalTime: String
    let boardingLocation: String
}

struct LocationInfo: Equatable {
    var name: String
    var longitude: Double
    var latitude: Double
}
