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
      
      VStack(spacing: 0.wScaled){
        
        VStack(spacing: 32.wScaled) {
          TopBar(isMoving: true) { coordinator.popToRoot() }
            .padding(.horizontal, 8.wScaled)
          
          if let journey {
              WholeJourney(
                  journey: journey,
                  journeyIndex: journey.nodes.count - 1,
                  isBeforeRide: false
              )
              .padding(.horizontal, 32.wScaled)
            }
          
          LineDivider()
        }
        .frame(height: 144.wScaled)
        ZStack {
          Color(.background)
            .ignoresSafeArea()
          VStack(alignment: .leading) {
            Spacer()
            if let destination = JourneyManager.shared.destination {
              MarqueeText(
                  text: destination.name,
                  font: .presemi36Scaled,
                  uiFont: .presemi36Scaled,
                  startDelay: 1.0,
                  alignment: .leading
              )
              .foregroundColor(Color.primaryHeavy)
            }
            Spacer()
            
            HStack{
              Spacer()
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 148.wScaled, weight: .bold))
                .foregroundColor(.subStrong)
                .rotation3DEffect(
                  .degrees(isAnimating ? 360 : 0),
                  axis: (x: 0, y: 1, z: 0)
                )
                .onAppear {
                  withAnimation(.easeOut(duration: 2.0)) {
                    isAnimating = true
                  }
//                  DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
//                    coordinator.popToRoot()
//                  }
                }
              Spacer()
            }
            Spacer()
            
            Text("도착")
              .font(.presemi32Scaled)
              .foregroundColor(.primaryHeavy)
            Text("했어요!")
              .font(.prereg32Scaled)
              .foregroundColor(.primaryHeavy)
              .padding(.bottom, 80.wScaled)
          }
          .padding(.horizontal,30.wScaled)
        }
      }
    }
  }
  
}
