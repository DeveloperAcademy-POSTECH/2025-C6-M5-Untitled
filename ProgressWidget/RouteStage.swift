
import Foundation

enum RouteStage: String, CaseIterable {
    case walkingToBus = "도보"
    case waitingForBus = "버스 대기"
    case onBus = "승차 중"
    case walkingToDestination = "목적지 도보"
    case atDestination = "도착"

    var description: String {
        switch self {
        case .walkingToBus:
            return "bus stop까지 걷기"
        case .waitingForBus:
            return "bus stop에서 승차하기"
        case .onBus:
            return "bus stop에서 하차하기"
        case .walkingToDestination:
            return "destination까지 걷기"
        case .atDestination:
            return "목적지 도착"
        }
    }
    
    var subDescription: String {
        switch self {
        case .walkingToBus:
            return "min분 정도 걸려요"
        case .waitingForBus:
            return "min분 동안 타아해요"
        case .onBus:
            return "n정류장 남았어요"
        case .walkingToDestination:
            return "min분 정도 걸려요"
        case .atDestination:
            return "도착을 축하합니다"
        }
    }

    
    var image: String {
        switch self {
        case .walkingToBus:
            return "figure.walk"
        case .waitingForBus:
            return "bus.fill"
        case .onBus:
            return "bus.fill"
        case .walkingToDestination:
            return "figure.walk"
        case .atDestination:
            return "party.popper.fill"
        }
    }
}
