import Foundation
import CoreLocation

final class BusLocationService {
    static let shared = BusLocationService()
    
    private let apiKey: String
    private let baseURL = "http://apis.data.go.kr/1613000"
    
    private init(apiKey: String = Secrets.tagoApiKey) {
        self.apiKey = apiKey
    }
    
    func fetchRouteBusLocations(
        cityCode: Int,
        routeId: String
    ) async throws -> [BusLocationItem] {
        
        let urlString = "\(baseURL)/BusLcInfoInqireService/getRouteAcctoBusLcList"
        
        let params: [String: String] = [
            "serviceKey": apiKey,
            "cityCode": "\(cityCode)",
            "routeId": routeId,
            "_type": "json",
            "numOfRows": "100",
            "pageNo": "1"
        ]
        
        let data = try await request(urlString: urlString, params: params)
        let decoded = try JSONDecoder().decode(BusLocationResponse.self, from: data)
        
        guard decoded.response.header.resultCode == "00" else {
            throw NSError(
                domain: "BusLocationService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: decoded.response.header.resultMsg]
            )
        }
        
        guard let body = decoded.response.body,
              let items = body.items else {
            return []
        }
        
        return items.item
    }
    
    // MARK: - 노선 정류장 순서 조회
    
    func fetchRouteStations(cityCode: Int, routeId: String) async throws -> [RouteStationItem] {
        let urlString = "\(baseURL)/BusRouteInfoInqireService/getRouteAcctoThrghSttnList"
        
        let params: [String: String] = [
            "serviceKey": apiKey,
            "cityCode": "\(cityCode)",
            "routeId": routeId,
            "numOfRows": "999",
            "pageNo": "1",
            "_type": "json"
        ]
        
        // 기존 request 헬퍼 사용
        let data = try await request(urlString: urlString, params: params)
        
        // 디버깅: 응답 내용 출력
        if let responseString = String(data: data, encoding: .utf8) {
            print("[BusLocationService] 응답 (첫 200자): \(String(responseString.prefix(200)))")
        }
        
        let decoded = try JSONDecoder().decode(RouteStationResponse.self, from: data)
        
        guard decoded.response.header.resultCode == "00" else {
            throw NSError(
                domain: "BusLocationService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: decoded.response.header.resultMsg]
            )
        }
        
        let stations = decoded.response.body?.items?.item ?? []
        
        print("[BusLocationService] 노선 \(routeId)의 정류장 \(stations.count)개 조회 완료")
        
        return stations
    }
    
    private func request(urlString: String, params: [String: String]) async throws -> Data {
        var components = URLComponents(string: urlString)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components?.url else {
            throw NSError(
                domain: "BusLocationService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "잘못된 URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "BusLocationService",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "잘못된 응답"]
            )
        }
        
        guard (200...299).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                print("[BusLocationService] HTTP \(http.statusCode) 에러 바디:\n\(body)")
            }
            throw NSError(
                domain: "BusLocationService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP 에러: \(http.statusCode)"]
            )
        }
        
        return data
    }
}
