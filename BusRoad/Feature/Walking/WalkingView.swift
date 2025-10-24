//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct WalkingView: View {
  @ObservedObject var vm = WalkingViewModel()
  @EnvironmentObject private var coordinator: NavigationCoordinator
  @State private var showAlert = false
  
  var journey: Journey?
  var index: Int?
  
  init(manager: JourneyManager = .shared) {
    if let journey = manager.selectedJourney, let index = manager.journeyIndex {
      self.journey = journey
      self.index = index
    }
  }
  
  var body: some View {
    ZStack {
      Color(.primarywhite)
        .ignoresSafeArea()
      
      VStack(spacing: 0){
        
        VStack(spacing: 0) {
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey, let index {
                        WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: false)
                            .padding(32)
                    }
                }
                .frame(height: 144)
                .onChange(of: vm.arrived) { _, newValue in
                    if newValue,
                       let journey = journey,
                       let index = index,
                       index == journey.nodes.count - 1 {
                        coordinator.advanceJourneyStage()
                    }
                }
        LineDivider()
        
        ZStack {
          Color(.background)
            .ignoresSafeArea()
          
          VStack {
            if let journey, let index {
              if vm.arrived {
                AtArrival(journey: journey, index: index)
              } else {
                ToDestination(vm:vm, journey: journey, index: index)
                
                Spacer()
                
                Button("이미 목적지에 도착하셨나요?") {
                  showAlert = true
                }
                .font(.premed12Scaled)
                .foregroundColor(.primaryHeavy)
                .underline()
              }
            }
          }
        }
      }
      .overlay(
        WalkingAlert(isPresented: $showAlert)
      )
    }
  }
}
