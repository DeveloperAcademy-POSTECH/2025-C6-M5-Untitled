//
//  BusRouteNode.swift
//  BusRoad
//
//  Created by 박난 on 10/5/25.
//

import SwiftUI

struct BusRouteNode {
    let id = UUID()
    let start: LocationInfo
    let end: LocationInfo
    let busNo: String
    let busId: Int
    let stations: [BusStation]  // [start ~ end] stations
    let travelTime: Int
}
