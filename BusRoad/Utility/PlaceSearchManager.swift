import Foundation

/// 네이버 지역 검색 API를 호출하는 매니저
final class PlaceSearchManager {
    private let clientID: String
    private let clientSecret: String

    init(
        clientID: String = Secrets.naverClientID,
        clientSecret: String = Secrets.naverClientSecret
    ) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    /// 네이버 키워드 검색
    func search(keyword: String, display: Int = 5, sort: String = "random") async throws -> [NaverLocalItem] {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host   = "openapi.naver.com"
        comps.path   = "/v1/search/local.json"
        comps.queryItems = [
            .init(name: "query", value: keyword),
            .init(name: "display", value: String(display)),
            .init(name: "sort", value: sort) // random=정확도, comment=리뷰순
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.addValue(clientID, forHTTPHeaderField: "X-Naver-Client-ID")
        req.addValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[HTTP] \(http.statusCode) [BODY] \(body)")
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(NaverLocalResponse.self, from: data)
        return decoded.items
    }
}
