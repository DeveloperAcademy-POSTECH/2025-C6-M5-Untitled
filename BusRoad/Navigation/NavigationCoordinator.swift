//
//  NavigationCoordinator.swift
//  BusRoad
//
//  Created by 박난 on 9/24/25.
//

import Combine
import Foundation

class NavigationCoordinator: ObservableObject {
    @Published var path: [Route] = []
    @Published var currentStage: JourneyStage?
    let journeyManager = JourneyManager.shared
    let searchManager = SearchManager.shared
    
    func push(_ path: Route) {
        self.path.append(path)
    }
    
    func pop() {
        if !self.path.isEmpty {
            self.path.removeLast()
        }
    }
    
    func popToRoot() {
        // manager 초기화
        journeyManager.reset()
        searchManager.reset()
        self.path.removeAll()
    }
    
    // 처음 JourneyStage 설정
    func setJourneyStage() {
        guard let journey = journeyManager.selectedJourney else { return print("[ERROR] There is no selectedJourney.") }
        guard let firstNode = journey.nodes.first else { return print("[ERROR] There is no firstNode.") }
        
        switch firstNode {
        case .bus:
            currentStage = .beforeRide
        case .walk:
            currentStage = .walking
        }
    }
    
    // 다음 JourneyStage 변경
    func advanceJourneyStage() {
        guard let index = journeyManager.journeyIndex else { return print("[ERROR] There is no journeyIndex.")}
        guard let journey = journeyManager.selectedJourney else { return print("[ERROR] There is no selectedJourney.") }
        
        if let currentStage {
            if index == journey.nodes.count - 1 {   // 마지막 요소일 경우, 승차 전을 제외하고(.walking, .onRide) 모두 congrats 뷰로 이동
                switch currentStage {
                case .beforeRide:
                    self.currentStage = .onRide
                default:
                    self.currentStage = .congrats
                }
            } else {
                switch currentStage {
                case .walking:
                    let nextNode = journey.nodes[index + 1]
                    switch nextNode {
                    case .bus:
                        self.currentStage = .beforeRide
                    case .walk:
                        break
                    }
                    journeyManager.journeyIndex = index + 1
                    
                case .beforeRide:   // [주의] 여기만 journeyIndex 안 올라감!!
                    self.currentStage = .onRide
                    
                case .onRide:
                    let nextNode = journey.nodes[index + 1]
                    switch nextNode {
                    case .walk:
                        self.currentStage = .walking
                    case .bus:
                        self.currentStage = .beforeRide
                    }
                    journeyManager.journeyIndex = index + 1
                    
                case .congrats:
                    print("[ERROR] There is no more stages.")
                }
            }
        }
    }
}
