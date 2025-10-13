//
//  RouteNode.swift
//  BusRoad
//
//  Created by 박난 on 10/5/25.
//

import SwiftUI

enum RouteNode {
    case bus(BusRouteNode)
    case walk(WalkRouteNode)
    
    var id: UUID {
        switch self {
        case .bus(let b): return b.id
        case .walk(let w): return w.id
        }
    }
    
    // 타입 가져오기
    var routeType: Any {
        switch self {
        case .bus(let busNode):
            return busNode
        case .walk(let walkNode):
            return walkNode
        }
    }
}
