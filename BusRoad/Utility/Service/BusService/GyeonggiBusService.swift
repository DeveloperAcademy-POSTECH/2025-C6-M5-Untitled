import Foundation

class GyeonggiBusService: BusServiceType {

    private let apiKey: String
    private let baseURL = "https://apis.data.go.kr/6410000/busarrivalservice/v2"

    init(apiKey: String = Secrets.tagoApiKey) {
        self.apiKey = apiKey
    }

    // MARK: - BusServiceType 프로토콜 구현

    func fetchNodeId(cityCode: Int, stationName: String, arsId: String?) async throws -> String {
        // 경기도는 stationId가 이미 있으므로 별도 조회 불필요
        // localStationId를 그대로 사용
        return ""
    }

    func fetchBusArrivalInfo(cityCode: Int, nodeId: String) async throws -> [BusArrivalItem] {
        return try await fetchBusArrivalList(stationId: nodeId)
    }

    // MARK: - 경기도 전용 API

    /// 정류소별 모든 노선 도착정보 조회
    func fetchBusArrivalList(stationId: String) async throws -> [BusArrivalItem] {
        let urlString = "\(baseURL)/getBusArrivalListv2"

        let params: [String: String] = [
            "serviceKey": apiKey,
            "stationId": stationId,
            "format": "json"
        ]

        print("[경기 도착정보 조회] stationId: \(stationId)")

        let data = try await request(urlString: urlString, params: params)

        // 디버깅용 원본 JSON 출력
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[경기 도착정보 응답 원본]")
            print(jsonString.prefix(1000))
        }

        let response = try JSONDecoder().decode(GyeonggiArrivalResponse.self, from: data)

        guard response.msgHeader.resultCode == 0 else {
            print("[경기 도착정보] API 오류: \(response.msgHeader.resultMessage)")
            throw NSError(
                domain: "GyeonggiBusService",
                code: response.msgHeader.resultCode,
                userInfo: [NSLocalizedDescriptionKey: response.msgHeader.resultMessage]
            )
        }

        guard let body = response.msgBody,
              let arrivalList = body.busArrivalList else {
            print("[경기 도착정보] 도착 정보 없음")
            return []
        }

        var resultItems: [BusArrivalItem] = []

        for item in arrivalList.items {
            // 첫 번째 버스
            if let busItem1 = item.toBusArrivalItem1() {
                resultItems.append(busItem1)
                print("  🚌 1번째: \(busItem1.routeno) - \(busItem1.arrtime)초")
            }

            // 두 번째 버스
            if let busItem2 = item.toBusArrivalItem2() {
                resultItems.append(busItem2)
                print("  🚌 2번째: \(busItem2.routeno) - \(busItem2.arrtime)초")
            }
        }

        print("[경기 도착정보 조회 성공] \(resultItems.count)개 버스 정보")
        return resultItems
    }

    /// 특정 노선의 도착정보 조회
    func fetchBusArrivalItem(stationId: String, routeId: String, staOrder: Int) async throws -> [BusArrivalItem] {
        let urlString = "\(baseURL)/getBusArrivalItemv2"

        let params: [String: String] = [
            "serviceKey": apiKey,
            "stationId": stationId,
            "routeId": routeId,
            "staOrder": String(staOrder),
            "format": "json"
        ]

        print("[경기 특정노선 도착정보] stationId: \(stationId), routeId: \(routeId), staOrder: \(staOrder)")

        let data = try await request(urlString: urlString, params: params)
        let response = try JSONDecoder().decode(GyeonggiArrivalResponse.self, from: data)

        guard response.msgHeader.resultCode == 0 else {
            throw NSError(
                domain: "GyeonggiBusService",
                code: response.msgHeader.resultCode,
                userInfo: [NSLocalizedDescriptionKey: response.msgHeader.resultMessage]
            )
        }

        guard let body = response.msgBody,
              let arrivalList = body.busArrivalList else {
            return []
        }

        var resultItems: [BusArrivalItem] = []

        for item in arrivalList.items {
            if let busItem1 = item.toBusArrivalItem1() {
                resultItems.append(busItem1)
            }
            if let busItem2 = item.toBusArrivalItem2() {
                resultItems.append(busItem2)
            }
        }

        return resultItems
    }

    // MARK: - 네트워크 요청

    private func request(urlString: String, params: [String: String]) async throws -> Data {
        var components = URLComponents(string: urlString)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components?.url else {
            throw NSError(
                domain: "GyeonggiBusService",
                code: -1,
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
                domain: "GyeonggiBusService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "잘못된 응답"]
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "GyeonggiBusService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP 에러: \(httpResponse.statusCode)"]
            )
        }

        return data
    }
}
