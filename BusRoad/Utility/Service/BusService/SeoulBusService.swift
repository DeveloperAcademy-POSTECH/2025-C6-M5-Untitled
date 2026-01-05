import Foundation

class SeoulBusService: BusServiceType {
    
    private let apiKey: String
    private let arriveByRouteURL = "http://ws.bus.go.kr/api/rest/arrive/getArrInfoByRoute"
    
    init(apiKey: String = Secrets.tagoApiKey) {
        self.apiKey = apiKey
    }
    
    func fetchNodeId(cityCode: Int, stationName: String, arsId: String?) async throws -> String { return "" }
    func fetchBusArrivalInfo(cityCode: Int, nodeId: String) async throws -> [BusArrivalItem] { return [] }
    
    func fetchBusArrivalByRoute(stId: String, busRouteId: String, ord: Int) async throws -> [BusArrivalItem] {
        
        var components = URLComponents(string: arriveByRouteURL)
        components?.queryItems = [
            URLQueryItem(name: "serviceKey", value: apiKey),
            URLQueryItem(name: "stId", value: stId),
            URLQueryItem(name: "busRouteId", value: busRouteId),
            URLQueryItem(name: "ord", value: String(ord)),
            URLQueryItem(name: "resultType", value: "json")
        ]
        
        guard let url = components?.url else {
            print("❌ URL 생성 실패")
            return []
        }
                
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpRes = response as? HTTPURLResponse else {
                print("❌ HTTP 응답 없음")
                return []
            }
            
            print("📡 응답 코드: \(httpRes.statusCode)")
            
            guard (200...299).contains(httpRes.statusCode) else {
                print("HTTP 오류: \(httpRes.statusCode)")
                return []
            }
            
            let decoded = try JSONDecoder().decode(SeoulArrivalResponse.self, from: data)

            print("🧾 headerCd=\(decoded.msgHeader?.headerCd ?? "nil") headerMsg=\(decoded.msgHeader?.headerMsg ?? "nil") itemCount=\(decoded.msgHeader?.itemCount ?? -1)")

            guard decoded.msgHeader?.headerCd == "0" else {
                print("API 실패")
                return []
            }

            guard let items = decoded.msgBody?.itemList else {
                print("⚠️ itemList 없음")
                return []
            }
            
            print("도착 정보 \(items.count)개 수신")
            
            var resultList: [BusArrivalItem] = []
            
            for item in items {
                // 첫번째 도착 정보
                let time1 = parseTime(from: item.arrmsg1)
                if time1 > 0 || item.arrmsg1.contains("곧도착") {
                    let arrItem = BusArrivalItem(
                        routeno: item.rtNm,
                        routeid: item.busRouteId,
                        arrtime: time1,
                        vehicletp: item.busType1,
                        arrprevstationcnt: 0
                    )
                    resultList.append(arrItem)
                    print("  🚌 1번째: \(item.rtNm) - \(time1)초 (\(item.arrmsg1))")
                }
                
                // 두번째 도착 정보
                let time2 = parseTime(from: item.arrmsg2)
                if time2 > 0 {
                    let arrItem = BusArrivalItem(
                        routeno: item.rtNm,
                        routeid: item.busRouteId,
                        arrtime: time2,
                        vehicletp: item.busType2,
                        arrprevstationcnt: 0
                    )
                    resultList.append(arrItem)
                    print("  🚌 2번째: \(item.rtNm) - \(time2)초 (\(item.arrmsg2))")
                }
            }
            
            return resultList
            
        } catch {
            print("❌ API 오류: \(error)")
            return []
        }
    }
    
    // 시간 파싱 로직
    private func parseTime(from message: String) -> Int {
        if message.contains("곧도착") { return 30 }
        if message.contains("출발대기") || message.contains("운행종료") { return 0 }
        
        var totalSeconds = 0
        
        // "분" 파싱
        if let range = message.range(of: "분"),
           let minutes = Int(message[..<range.lowerBound]) {
            totalSeconds += minutes * 60
        }
        
        // "초" 파싱
        let components = message.components(separatedBy: "분")
        let secondPart = components.count > 1 ? components[1] : message
        if let range = secondPart.range(of: "초"),
           let seconds = Int(secondPart[..<range.lowerBound].trimmingCharacters(in: .whitespaces)) {
            totalSeconds += seconds
        }
        
        return totalSeconds
    }
}

