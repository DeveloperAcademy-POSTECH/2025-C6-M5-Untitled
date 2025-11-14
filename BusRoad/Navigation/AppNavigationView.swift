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
                .navigationBarBackButtonHidden(true)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .routeSuggestion:
                        RouteSuggestionView()
                            .toolbar(.hidden, for: .navigationBar)
                    case .mainSearch:
                        MainSearchView()
                            .toolbar(.hidden, for: .navigationBar)
                    case .voiceSearch:
                        VoiceSearchView()
                            .toolbar(.hidden, for: .navigationBar)
                    case .journeyFlow:
//                        JourneyFlowView()
//                            .toolbar(.hidden, for: .navigationBar)
                        EmptyView()
                    }
                }
                .fullScreenCover(isPresented: $coordinator.isJourneyFlowPresented) {
                    JourneyFlowView()
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
    }
}
