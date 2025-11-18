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
    @Published var isJourneyFlowPresented: Bool = false
    @Published var isReturningFromRoute: Bool = false
    
    let journeyManager = JourneyManager.shared
    let searchManager = SearchManager.shared
    
    func push(_ path: Route) {
        if path == .journeyFlow {
            self.isJourneyFlowPresented = true
            return
        }
        self.path.append(path)
    }
    
    func pop() {
            if !self.path.isEmpty {
                // pop하기 전에 현재 route 확인
                let currentRoute = self.path.last
                self.path.removeLast()
                
                // routeSuggestion에서 돌아오는 경우 플래그 설정
                if currentRoute == .routeSuggestion {
                    isReturningFromRoute = true
                }
            }
        }

    
    func popToRoot() {
        self.isJourneyFlowPresented = false
        self.currentStage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.path.removeAll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // manager 초기화
            self.journeyManager.reset()
            self.searchManager.reset()
            
            LocationService.shared.invalidateCache()
            
        }
    }
    
    // 처음 JourneyStage 설정
    func setJourneyStage() {
        guard let journey = journeyManager.selectedJourney else { return }
        guard let firstNode = journey.nodes.first else { return }
        
        switch firstNode {
        case .bus:
            currentStage = .beforeRide
        case .walk:
            currentStage = .walking
        }
    }
    
    // 다음 JourneyStage 변경
    func advanceJourneyStage() {
        guard let index = journeyManager.journeyIndex else { return }
        guard let journey = journeyManager.selectedJourney else { return }
        
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
