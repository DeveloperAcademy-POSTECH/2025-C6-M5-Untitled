//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct WalkingView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    var body: some View {
        // 임시 버튼. 지워도 됨!
        Button {
            Text("다음 노드로 가는 임시 버튼!!")
        } label: {
            coordinator.advanceJourney()
        }
    }
}
