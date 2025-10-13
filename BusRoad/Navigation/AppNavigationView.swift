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
            MainSearchView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .routeSuggestion:
                        RouteSuggestionView()
                    case .mainSearch:
                        MainSearchView()
                    case .voiceSearch:
                        VoiceSearchView()
                    case .journeyFlow:
                        JourneyFlowView()
                    }
                }
        }
    }
}
