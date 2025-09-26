//
//  Route.swift
//  BusRoad
//
//  Created by 박난 on 9/24/25.
//

import Foundation
import SwiftUI

enum Route: Hashable {
    case textSearch
    case voiceSearch
    case routeSuggestion
    case walking
    case beforeRide
    case onRide
    case congrats
}
