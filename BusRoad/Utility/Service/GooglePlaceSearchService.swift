//
//  GooglePlaceSearchService.swift
//  BusRoad
//
//  Created by 박난 on 1/30/26.
//

import Foundation

final class GooglePlaceSearchService {
    
    private let apiKey: String
    
    init(apiKey: String = Secrets.googleApiKey) {
        self.apiKey = apiKey
    }
    
    func searchByText(
        query: String,
        language: String = "en",
        countryCode: String = "kr",
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Int = 5000
    ) async throws -> [GooglePlace] {
        
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "maps.googleapis.com"
        comps.path = "/maps/api/place/textsearch/json"
        
        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        if let lat = latitude, let lon = longitude {
            queryItems.append(URLQueryItem(name: "location", value: "\(lat),\(lon)"))
            queryItems.append(URLQueryItem(name: "radius", value: "\(radius)"))
        }
        
        comps.queryItems = queryItems
        
        guard let url = comps.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Google Places API Error] 상태코드: \(http.statusCode)")
            print("[응답 내용] \(body)")
            
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(GoogleTextSearchResponse.self, from: data)
        
        guard decoded.status == "OK" || decoded.status == "ZERO_RESULTS" else {
            print("[Google Places API Error] Status: \(decoded.status)")
            throw URLError(.badServerResponse)
        }
        
        return decoded.results
    }
}
