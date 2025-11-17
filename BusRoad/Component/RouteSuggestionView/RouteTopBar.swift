//
//  RouteTopBar.swift
//  BusRoad
//
//  Created by 박난 on 11/14/25.
//

import SwiftUI

struct RouteTopBar: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var body: some View {
        ZStack {
            HStack {
                Spacer()
                Text("경로 탐색")
                    .font(.presemi18Scaled)
                    .foregroundStyle(.primaryblack)
                Spacer()
            }
            HStack {
                Button {
                    coordinator.pop()
                } label: {
                    Image("gotoback")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20.wScaled, height: 20.wScaled)
                        .foregroundColor(.greyNormal)
                }
                Spacer()
            }
        }
    }
}
