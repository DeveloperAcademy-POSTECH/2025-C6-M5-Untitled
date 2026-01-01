
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
        case .onBus:
            return "RouteBusIcon"
        case .waitingForBus:
            return "RouteBusWait"
        }
    }
    
    var minimalImage: String {
        switch self {
        case  .walkingToDestination, .walkingToBus:
            return "WalkingIcon"
        case .onBus:
            return "BusIcon"
        case .waitingForBus:
            return "TimerIcon"
        }
    }
    var expandImage: String {
        switch self {
        case  .walkingToDestination, .walkingToBus:
            return "expandwalk"
        case .onBus:
            return "expandbus"
        case .waitingForBus:
            return "expandbuswait"
        }
    }
}
