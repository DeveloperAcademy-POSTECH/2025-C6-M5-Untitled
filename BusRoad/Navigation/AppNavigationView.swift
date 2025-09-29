//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct AppNavigationView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var mainVM = MainSearchViewModel()
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            MainSearchView()
                .environmentObject(mainVM)
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
                    case .mainSearch:
                        MainSearchView()
                            .environmentObject(mainVM)
                    case .voiceSearch:
                        VoiceSearchView(
                            mainSearchVM: mainVM
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
