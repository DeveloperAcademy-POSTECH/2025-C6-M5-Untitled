//
//  BusRoadApp.swift
//  BusRoad
//
//  Created by Ella's Mac on 9/19/25.
//

import SwiftUI

@main
struct BusRoadApp: App {
    @StateObject var coordinator = NavigationCoordinator()
    @StateObject private var proximityManager = AlightProximityManager(
        locationService: LocationService.shared,
        journeyManager: JourneyManager.shared,
        voiceManager: VoiceAnnouncementManager()
    )
    
    init() {
        _ = BusDataManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            AppNavigationView()
                .environmentObject(coordinator)
                .environmentObject(proximityManager)
        }
    }
}
