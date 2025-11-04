//
//  JourneyFlowView.swift
//  BusRoad
//
//  Created by 박난 on 10/14/25.
//
import SwiftUI

struct JourneyFlowView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var body: some View {
        Group {
            switch coordinator.currentStage {
            case .walking:
                WalkingView()
            case .beforeRide:
                BeforeRideView()
            case .onRide:
                OnRideView()
            case .congrats:
                CongratsView()
            case .none:
                ProgressView("경로 불러오는 중...")
                    .tint(.greyDisable)
            }
        }
        .onAppear {
            if coordinator.currentStage == nil {
                coordinator.setJourneyStage()
            }
        }
    }
}
