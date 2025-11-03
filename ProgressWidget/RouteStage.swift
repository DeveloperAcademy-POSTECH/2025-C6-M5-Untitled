
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
    
    // 🔹 다크모드 대응 이미지 반환
    func image(forDarkMode darkMode: Bool) -> String {
        let baseName = self.image
        return darkMode ? "\(baseName)DarkMode" : baseName
    }
}
