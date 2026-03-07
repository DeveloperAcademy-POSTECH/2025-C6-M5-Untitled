import Foundation

class TagoBusService: BusServiceType {
    private let apiKey: String
    private let baseURL = "http://apis.data.go.kr/1613000"
    
    init(apiKey: String = Secrets.tagoApiKey) {
        self.apiKey = apiKey
    }
    
    // nodeId 조회하기
    func fetchNodeId(cityCode: Int, stationName: String, arsId: String? = nil) async throws -> String {
        let urlString = "\(baseURL)/BusSttnInfoInqireService/getSttnNoList"
        
        var params: [String: String] = [
            "serviceKey": apiKey,
            "cityCode": "\(cityCode)",
            "nodeNm": stationName,
            "_type": "json",
            "numOfRows": "10",
            "pageNo": "1"
        ]
        
        // arsId가 있을 경우에만 nodeNo 파라미터 추가
        if let arsId = arsId, !arsId.isEmpty {
            params["nodeNo"] = arsId
        }
        
        print("[nodeId 조회] cityCode: \(cityCode), 정류소: \(stationName), arsId: \(arsId ?? "없음")")
        
        let data = try await request(urlString: urlString, params: params)
        let response = try JSONDecoder().decode(NodeIdResponse.self, from: data)
        
        guard response.response.header.resultCode == "00" else {
            throw NSError(
                domain: "BusArrivalService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.response.header.resultMsg]
            )
        }
        
        guard let item = response.response.body?.items.item.first else {
            throw NSError(
                domain: "BusArrivalService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "정류소를 찾을 수 없습니다"]
            )
        }
        
        print("[nodeId 조회 성공] nodeId: \(item.nodeid)")
        return item.nodeid
    }
    
    // 버스 도착 정보 조회하기
    func fetchBusArrivalInfo(cityCode: Int, nodeId: String) async throws -> [BusArrivalItem] {
        let urlString = "\(baseURL)/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList"
        
        let params: [String: String] = [
            "serviceKey": apiKey,
            "cityCode": "\(cityCode)",
            "nodeId": nodeId,
            "_type": "json",
            "numOfRows": "100",
            "pageNo": "1"
        ]
        
        print("[도착정보 조회] cityCode: \(cityCode), nodeId: \(nodeId)")
        
        let data = try await request(urlString: urlString, params: params)
        
        // 원본 JSON 출력 (디버깅용)
//        if let jsonString = String(data: data, encoding: .utf8) {
//            print("[도착정보 응답 원본 JSON]")
//            print(jsonString)
//        }
        
        let response = try JSONDecoder().decode(BusArrivalResponse.self, from: data)
        
        guard response.response.header.resultCode == "00" else {
            throw NSError(
                domain: "BusArrivalService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.response.header.resultMsg]
            )
        }
        
        guard let body = response.response.body else {
            print("[도착정보 조회] body가 없음")
            return []
        }
        
        if body.totalCount == 0 {
            print("[도착정보 조회] totalCount = 0 (도착 예정 버스 없음)")
            return []
        }
        
        guard let items = body.items else {
            print("[도착정보 조회] items가 nil")
            return []
        }
        
        print("[도착정보 조회 성공] \(items.item.count)개 버스 정보")
        return items.item
    }
    
    // 공통 네트워크 요청 함수 (async)
    private func request(urlString: String, params: [String: String]) async throws -> Data {
        var components = URLComponents(string: urlString)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components?.url else {
            throw NSError(
                domain: "BusArrivalService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "잘못된 URL"]
            )
        }
        
        print("요청 URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "BusArrivalService",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "잘못된 응답"]
            )
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "BusArrivalService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP 에러: \(httpResponse.statusCode)"]
            )
        }
        
        return data
    }
}
