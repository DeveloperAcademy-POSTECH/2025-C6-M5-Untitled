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
    
    // 버스 구간이 하나도 없으면 도보-only 경로 분기처리
    var isWalkingOnly: Bool {
        firstBusRoute == nil
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

    /// 주어진 nodeIndex(전체 경로 기준)가 몇 번째 버스 구간인지(0-based) 환산
    /// - 예: [bus, walk, bus] 에서 nodeIndex=0 → 0, nodeIndex=2 → 1
    func busLegIndex(forNodeIndex nodeIndex: Int) -> Int? {
        guard nodes.indices.contains(nodeIndex) else { return nil }
        var count = 0
        for i in 0...nodeIndex {
            if case .bus = nodes[i] { count += 1 }
        }
        // 해당 지점까지 등장한 버스 구간 수 - 1 이 현재 버스 구간 인덱스
        return count > 0 ? (count - 1) : nil
    }

    /// nodeIndex를 바로 하차 정류장 LocationInfo로 매핑하고 싶을 때
    func alightStop(forNodeIndex nodeIndex: Int) -> LocationInfo? {
        guard let leg = busLegIndex(forNodeIndex: nodeIndex) else { return nil }
        return alightStop(ofBusLeg: leg)
    }
}
