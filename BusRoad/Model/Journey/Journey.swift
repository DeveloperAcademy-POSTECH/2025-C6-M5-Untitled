import SwiftUI

struct Journey: Identifiable, Equatable {
    let id = UUID()
    let totalTime: Int  // 총 걸리는 시간
    var nodes: [RouteNode]

    init(totalTime: Int, nodes: [RouteNode]) {
        self.totalTime = totalTime
        self.nodes = nodes
    }

    static func == (lhs: Journey, rhs: Journey) -> Bool {
        lhs.id == rhs.id
    }
    
    // route 중 첫 번째 BusRouteNode를 가져오기
    var firstBusRoute: BusRouteNode? {
        nodes.compactMap { node in
            if case let .bus(busNode) = node {
                return busNode
            } else {
                return nil
            }
        }.first
    }
}
