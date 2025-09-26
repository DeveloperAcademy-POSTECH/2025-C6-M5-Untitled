//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct TextSearchView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    var body: some View {
        VStack {
            Text("어디로 갈까요?")
                .font(.title)
                .bold()
            
            Button {
                coordinator.push(.voiceSearch)
            } label: {
                Text("Move to VoiceSearch")
            }
        }
    }
}

#Preview {
    TextSearchView()
}
