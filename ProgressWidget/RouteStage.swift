
import Foundation

enum RouteStage: String, CaseIterable {
    case walkingToBus
    case waitingForBus
    case onBus
    case walkingToDestination

    var image: String {
        switch self {
        case .walkingToBus, .walkingToDestination:
            return "RouteWalkingIcon"
        case .waitingForBus, .onBus:
            return "RouteBusIcon"
        }
    }
    
    var minimalImage: String {
        switch self {
        case  .walkingToDestination, .walkingToBus:
            return "WalkingIcon"
        case .waitingForBus, .onBus:
            return "BusIcon"
        }
    }
    var expandImage: String {
        switch self {
        case  .walkingToDestination, .walkingToBus:
            return "expandwalk"
        case .waitingForBus, .onBus:
            return "expandbus"
        }
    }
}
