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
    var body: some Scene {
        WindowGroup {
//            ContentView()
            AppNavigationView()
                .environmentObject(coordinator)
        }
    }
}
