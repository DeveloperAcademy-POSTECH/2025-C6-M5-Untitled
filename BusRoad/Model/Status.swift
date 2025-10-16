//
//  Status.swift
//  BusRoad
//
//  Created by 박난 on 10/14/25.
//

// WholeJourney의 RouteCircle 컴포넌트 상태 표시
enum Status {
    case active
    case disable
    
    mutating func toggle() {
        switch self {
        case .active:
            self = .disable
        case .disable:
            self = .active
        }
    }
}
