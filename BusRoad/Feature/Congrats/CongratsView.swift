//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct CongratsView: View {
  @EnvironmentObject private var coordinator: NavigationCoordinator
  @State private var isAnimating = false
  
  @State private var journey: Journey? = JourneyManager.shared.selectedJourney
  
  var body: some View {
    ZStack {
      Color(.primarywhite)
        .ignoresSafeArea()
      
      VStack(spacing: 0){
        
        VStack(spacing: 32) {
          TopBar(isMoving: true) { coordinator.popToRoot() }
            .padding(.horizontal, 8)
          
          if let journey {
              WholeJourney(
                  journey: journey,
                  journeyIndex: journey.nodes.count - 1,
                  isBeforeRide: false
              )
              .padding(.horizontal, 32)
            }
          
          LineDivider()
        }
        .frame(height: 144)
        ZStack {
          Color(.background)
            .ignoresSafeArea()
          VStack(alignment: .leading) {
            Spacer()
            if let destination = JourneyManager.shared.destination {
              Text(destination.name)
                .font(.presemi36)
                .foregroundColor(.primaryHeavy)
            }
            Spacer()
            
            HStack{
              Spacer()
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 148, weight: .bold))
                .foregroundColor(.subStrong)
                .rotation3DEffect(
                  .degrees(isAnimating ? 360 : 0),
                  axis: (x: 0, y: 1, z: 0)
                )
                .onAppear {
                  withAnimation(.easeOut(duration: 2.0)) {
                    isAnimating = true
                  }
                }
              Spacer()
            }
            Spacer()
            
            Text("도착")
              .font(.presemi32)
              .foregroundColor(.primaryHeavy)
            Text("했어요!")
              .font(.prereg32)
              .foregroundColor(.primaryHeavy)
              .padding(.bottom, 80)
          }
          .padding(.horizontal,30)
        }
      }
    }
  }
  
}
