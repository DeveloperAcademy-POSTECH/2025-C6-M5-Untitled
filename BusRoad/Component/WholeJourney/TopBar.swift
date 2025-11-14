//
//  TopBar.swift
//  BusRoad
//
//  Created by 박난 on 10/15/25.
//
import SwiftUI

struct TopBar: View {
    @State private var journey: Journey? = JourneyManager.shared.selectedJourney
    @State private var showAlert = false
    var isMoving: Bool
    var onXMark: () -> Void
    
    var body: some View {
        ZStack {
            HStack {
                Spacer()
                Text(titleText)
                    .font(.presemi18Scaled)
                    .foregroundStyle(.primaryblack)
                Spacer()
            }
            HStack {
                Spacer()
                Button {
                    if journey == nil {
                        onXMark()
                    } else {
                        withAnimation(.none) {
                            showAlert = true
                        }
                        ProgressLiveActivityManager.shared.endActivity()
                    }
                } label: {
                    Image("xbutton")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44.wScaled, height: 44.wScaled)
                        .foregroundColor(.greyNormal)
                }
            }
        }
        .fullScreenCover(isPresented: $showAlert) {
            StopNavigationAlert(isPresented: $showAlert, onXMark: onXMark)
                .presentationBackground(.clear)
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
    }
    
    private var titleText: String {
        if !isMoving {
            return "경로 탐색"
        }
        
        guard let journey = JourneyManager.shared.selectedJourney,
              let index = JourneyManager.shared.journeyIndex,
              index < journey.nodes.count else {
            return "경로 이동"
        }
        
        let currentNode = journey.nodes[index]
        
        switch currentNode {
        case .walk(let walkNode):
            if index == 0 {
                return "도보 이동"
            } else {
                return "도보 이동"
            }
        case .bus:
            return "버스 이동"
        }
    }
}
