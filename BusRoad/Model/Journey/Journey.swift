import SwiftUI

struct Journey: Identifiable, Equatable {
    let id = UUID()
    let totalTime: Int  // 총 걸리는 시간
    var nodes: [RouteNode]
    let routeType: String
    
    init(totalTime: Int, nodes: [RouteNode], routeType: String) {
        self.totalTime = totalTime
        self.nodes = nodes
        self.routeType = routeType
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
    
    // 환승 횟수
    var transferCount: Int {
        let busSegments = nodes.compactMap { node -> BusRouteNode? in
            if case let .bus(b) = node { return b } else { return nil }
        }
        return max(0, busSegments.count - 1)
    }
    
    // 도보 시간
    var walkingTime: Int {
        nodes.reduce(0) { acc, node in
            switch node {
            case .walk(let w): return acc + w.travelTime
            case .bus:         return acc
            }
        }
    }
}


//  TODO: 따로 파일 정리
// 마지막 정류장 뽑아오기 위한 extension
extension Journey {
    var busSegments: [BusRouteNode] {
        nodes.compactMap { if case let .bus(b) = $0 { b } else { nil } }
    }

    /// N번째 버스 구간에서 내릴 정류장(0-based)
    func alightStop(ofBusLeg index: Int) -> LocationInfo? {
        guard busSegments.indices.contains(index) else { return nil }
        return busSegments[index].end
    }
}
