import Foundation

class GyeonggiBusService: BusServiceType {

    private let apiKey: String
    private let baseURL = "https://apis.data.go.kr/6410000/busarrivalservice/v2"

    init(apiKey: String = Secrets.gyeonggiApiKey) {
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

        let data = try await request(urlString: urlString, params: params)
        let decoded = try JSONDecoder().decode(GyeonggiArrivalResponse.self, from: data)
        let header = decoded.response.msgHeader

        guard header.resultCode == 0 else {
            print("[경기 도착정보] API 오류: \(header.resultMessage)")
            throw NSError(
                domain: "GyeonggiBusService",
                code: header.resultCode,
                userInfo: [NSLocalizedDescriptionKey: header.resultMessage]
            )
        }

        guard let body = decoded.response.msgBody,
              let arrivalList = body.busArrivalList else {
            print("[경기 도착정보] 도착 정보 없음")
            return []
        }

        var resultItems: [BusArrivalItem] = []

        for item in arrivalList {
            // 첫 번째 버스
            if let busItem1 = item.toBusArrivalItem1() {
                resultItems.append(busItem1)
            }

            // 두 번째 버스
            if let busItem2 = item.toBusArrivalItem2() {
                resultItems.append(busItem2)
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

        let data = try await request(urlString: urlString, params: params)
        let decoded = try JSONDecoder().decode(GyeonggiArrivalResponse.self, from: data)
        let header = decoded.response.msgHeader

        guard header.resultCode == 0 else {
            throw NSError(
                domain: "GyeonggiBusService",
                code: header.resultCode,
                userInfo: [NSLocalizedDescriptionKey: header.resultMessage]
            )
        }

        guard let body = decoded.response.msgBody,
              let arrivalList = body.busArrivalList else {
            return []
        }

        var resultItems: [BusArrivalItem] = []

        for item in arrivalList {
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
        // serviceKey의 + 문자를 %2B로 인코딩하기 위해 URL을 직접 구성
        var queryParts: [String] = []
        for (key, value) in params {
            if key == "serviceKey" {
                // serviceKey는 +, = 등 특수문자를 명시적으로 percent encoding
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
                queryParts.append("\(key)=\(encoded)")
            } else {
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                queryParts.append("\(key)=\(encoded)")
            }
        }

        let fullURLString = urlString + "?" + queryParts.joined(separator: "&")

        guard let url = URL(string: fullURLString) else {
            throw NSError(
                domain: "GyeonggiBusService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "잘못된 URL"]
            )
        }

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
