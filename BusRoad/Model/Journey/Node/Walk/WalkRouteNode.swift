//
//  WalkRouteNode.swift
//  BusRoad
//
//  Created by 박난 on 10/5/25.
//

import SwiftUI
import CoreLocation

struct WalkRouteNode {
    let id = UUID()
    
    var start: LocationInfo   // 도보 출발지점
    var end: LocationInfo     // 도보 목적지점
    let travelTime: Int       // 도보 시간
    
    var asRouteNode: RouteNode { .walk(self) }
}
