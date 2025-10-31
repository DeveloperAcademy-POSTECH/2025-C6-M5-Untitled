

import Foundation

struct JourneyLite {
    var nodes: [RouteNodeLite]
}

enum RouteNodeLite {
    case walk(WalkNodeLite)
    case bus(BusNodeLite)
}

struct WalkNodeLite { let totalDistance: Int }
struct BusNodeLite { let totalBusStops: Int }
//
