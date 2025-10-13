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
            HStack {
                Spacer()
                Button {
                    coordinator.popToRoot()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                        .foregroundColor(.greyNormal)
                }
            }
            Spacer()
            Text("Congratulations!")
            Spacer()
        }
    }
}
