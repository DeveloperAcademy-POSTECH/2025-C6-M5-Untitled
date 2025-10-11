//
//  PlaceSummary.swift
//  BusRoad
//
//  Created by 박난 on 10/4/25.
//

import SwiftUI

//MARK: - 화면전달용 DTO
struct PlaceSummary: Hashable, Identifiable, Codable {
    var id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}
