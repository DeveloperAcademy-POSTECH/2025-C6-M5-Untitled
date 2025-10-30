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
    var busNo: [String]         // 리스트로 받음. 바뀔 수 있도록 var
    let busId: Int
    let stations: [BusStation]  // [start ~ end] stations
    let travelTime: Int
    
    var asRouteNode: RouteNode { .bus(self) }   // RouteNode로서 취급
}
