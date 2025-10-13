//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct WalkingView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    var journey: Journey?
    var index: Int?
    
    init(manager: JourneyManager = .shared) {
        if let journey = manager.selectedJourney, let index = manager.journeyIndex {
            self.journey = journey
            self.index = index
        }
    }
    
    var body: some View {
        // 임시 화면
        VStack {
            
            if let journey, let index {
                WholeJourney(journey: journey, journeyIndex: index)
                    .padding(.horizontal, 30)
            }
            
            Spacer()
            
            Button {
                coordinator.advanceJourneyStage()
            } label: {
                Text("도보뷰입니다. -> 다음 노드로 가는 임시 버튼!!")
            }
            
            Spacer()
        }
    }
}
