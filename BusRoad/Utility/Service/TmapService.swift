import CoreLocation
import Foundation

final class TmapService {
    private let apiKey: String
    
    init(apiKey: String = Secrets.tmapApiKey) {
        self.apiKey = apiKey
    }
    
    // 보행자 경로 요청
    func getPedestrianRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async throws -> TmapPedestrianResponse {
        
        let urlString = "https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        print("[TMAP] 보행자 경로 요청 시작")
        print("출발: (\(start.latitude), \(start.longitude))")
        print("도착: (\(end.latitude), \(end.longitude))")
        
        // 요청 바디
        let body: [String: Any] = [
                "startX": start.longitude,  // 경도
                "startY": start.latitude,   // 위도
                "endX": end.longitude,
                "endY": end.latitude,
                "startName": "출발지",
                "endName": "목적지"
            ]
        
        // JSON 변환
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        print("요청 바디: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        // HTTP 요청 설정
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        
        // 헤더 설정
        request.addValue(apiKey, forHTTPHeaderField: "appKey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // 응답
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("[TMAP] 응답 받음")
        
        if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[TMAP Error] 상태코드: \(http.statusCode)")
                print("응답: \(body)")
                throw URLError(.badServerResponse)
            }
        
       
        
        //  Swift 모델 변환
            let decoded = try JSONDecoder().decode(TmapPedestrianResponse.self, from: data)
            
            print("[TMAP] 총 거리: \(decoded.features.first?.properties.totalDistance ?? 0)m")
            print("[TMAP] 총 시간: \(decoded.features.first?.properties.totalTime ?? 0)초")
            
            return decoded
    }
}
