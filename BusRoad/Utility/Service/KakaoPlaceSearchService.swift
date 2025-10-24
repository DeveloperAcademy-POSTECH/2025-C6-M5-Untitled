import Foundation

final class KakaoPlaceSearchService {
    
    private let apiKey: String
    
    init(apiKey: String = Secrets.kakaoApiKey) {
        self.apiKey = apiKey
    }
    
    enum SearchSort: String {
        case distance = "distance"  // 거리순
        case accuracy = "accuracy"  // 정확도순
    }
    
    
    // MARK: - 키워드 검색
    func searchByKeyword (
        keyword: String,
        x: Double? = nil,
        y: Double? = nil,
        size: Int = 15
    ) async throws -> [KakaoPlace] {
        
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "dapi.kakao.com"
        comps.path = "/v2/local/search/keyword.json"
        
        var queryItems = [
            URLQueryItem(name: "query", value: keyword),
            URLQueryItem(name: "size", value: String(size))
            ]
        
        if let x = x, let y = y {
            // 내 위치 추가
            queryItems.append(URLQueryItem(name: "x", value: String(x)))
            queryItems.append(URLQueryItem(name: "y", value: String(y)))
            
            queryItems.append(URLQueryItem(name: "sort", value: "accuracy"))
        } else {
            // 위치 없는 경우
            queryItems.append(URLQueryItem(name: "sort", value: "accuracy"))
        }
        
        comps.queryItems = queryItems

        
        guard let url = comps.url else {
               throw URLError(.badURL)
           }
        
        print("만들어진 URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        request.addValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // API 호출
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
            
                // 에러 내용 출력
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[Kakao API Error] 상태코드: \(http.statusCode)")
                print("[응답 내용] \(body)")
                
                throw URLError(.badServerResponse)
            }
        
        let decoded = try JSONDecoder().decode(KakaoKeywordResponse.self, from: data)
        
        return decoded.documents
    }
    
    
    // MARK: - 주소 검색
    
    func searchByAddress(
        address: String,
        size: Int = 10
    ) async throws -> [KakaoAddressDocument] {
        
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "dapi.kakao.com"
        comps.path = "/v2/local/search/address.json"
        
        comps.queryItems = [
            URLQueryItem(name: "query", value: address),
            URLQueryItem(name: "size", value: "\(size)")
        ]
       
        guard let url = comps.url else {
            throw URLError(.badURL)
        }
        
        print("만들어진 URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[Kakao API Error] 상태코드: \(http.statusCode)")
                print("[응답 내용] \(body)")
                throw URLError(.badServerResponse)
            }
        
        let decoded = try JSONDecoder().decode(KakaoAddressResponse.self, from: data)
        
        return decoded.documents
    }
    
    
}
