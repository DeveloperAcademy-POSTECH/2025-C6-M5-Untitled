//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct AppNavigationView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            TextSearchView()
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
                    case .voiceSearch:
                        VoiceSearchView()
                    case .walking:
                        WalkingView()
                    }
                }
        }
    }
}
