//
//  NavigationCoordinator.swift
//  BusRoad
//
//  Created by 박난 on 9/24/25.
//

import Foundation
import Combine

class NavigationCoordinator: ObservableObject {
    @Published var path: [Route] = []
    
    func push(_ path: Route) {
        self.path.append(path)
    }

    func pop() {
        if !self.path.isEmpty {
            self.path.removeLast()
        }
    }

    func popToRoot() {
        self.path.removeAll()
    }
}
