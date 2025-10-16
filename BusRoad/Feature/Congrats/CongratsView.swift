//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct CongratsView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    var body: some View {
        VStack {
            TopBar(isMoving: true) { coordinator.popToRoot() }
            Spacer()
            Text("Congratulations!")
            Spacer()
        }
    }
}
