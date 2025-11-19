//
//  LocationStore.swift
//  BusRoad
//
//  Created by 박난 on 11/18/25.
//
import SwiftUI
import Combine

class LocationStore: ObservableObject {
    @Published var locations: [PlaceSummary] = [] {
        didSet { save() }
    }
    
    private let key = "savedLocations"
    
    init() {
        load()
    }
    
    /// 최대 10개까지 추가
    func add(_ location: PlaceSummary) {
        // 이름 기준으로 중복 판단
        if let index = locations.firstIndex(where: {
            $0.name == location.name
        }) {
            locations.remove(at: index)
            print("[DEBUG] 최근검색어: 중복 제거")
        }

        locations.insert(location, at: 0)

        if locations.count > 10 {
            locations = Array(locations.prefix(10))
        }
    }
    
    private func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(locations) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func remove(_ location: PlaceSummary) {
        if let index = locations.firstIndex(of: location) {
            locations.remove(at: index)
        }
    }
    
    private func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? decoder.decode([PlaceSummary].self, from: data) {
            self.locations = decoded
        }
    }
}
