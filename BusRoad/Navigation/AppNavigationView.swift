//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct AppNavigationView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var textVM = TextSearchViewModel()
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            TextSearchView()
                .environmentObject(textVM)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .beforeRide:
                        BeforeRideView()
                    case .congrats:
                        CongratsView()
                    case .onRide:
                        OnRideView()
                    case .routeSuggestion:
                        RouteSuggestionView()
                    case .textSearch:
                        TextSearchView()
                            .environmentObject(textVM)
                    case .voiceSearch:
                        VoiceSearchView(
                            textSearchVM: textVM
                        ) { _ in
                            coordinator.pop()
                        }
                    case .walking:
                        WalkingView()
                    }
                }
        }
    }
}
