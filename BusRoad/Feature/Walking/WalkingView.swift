//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct WalkingView: View {
  @ObservedObject var vm = WalkingViewModel()

  var journey: Journey?
  var index: Int?
  
  init(manager: JourneyManager = .shared) {
    if let journey = manager.selectedJourney, let index = manager.journeyIndex {
      self.journey = journey
      self.index = index
    }
  }
  
  var body: some View {
    ZStack{
        Rectangle()
          .fill(Color.background)
          .stroke(Color.greyDisable, lineWidth: 0.5)
          .frame(maxWidth: .infinity, maxHeight: 615)
          .offset(y: UIScreen.main.bounds.height / 2 - 615 / 2 - 10)
      
      VStack {
        if let journey, let index {
          WholeJourney(journey: journey, journeyIndex: index,
//                       isBeforeRide: false
          )
            .padding(.top, 40)

          if vm.arrived {
              AtArrival(journey: journey, index: index)
          } else {
            ToDestination(vm:vm, journey: journey, index: index)
          }
        }
      }
      
    }
  }
}
