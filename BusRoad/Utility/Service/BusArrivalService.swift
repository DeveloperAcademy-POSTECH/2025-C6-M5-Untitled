import Foundation

class BusArrivalService {
    private let apiKey: String
    private let baseURL = "http://apis.data.go.kr/1613000"
    
    init(apiKey: String = Secrets.tagoApiKey) {
        self.apiKey = apiKey
    }
    
    // nodeId 조회하기
    func fetchNodeId(
        cityCode: Int,
        stationName: String,
        arsId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let urlString = "\(baseURL)/BusSttnInfoInqireService/getSttnNoList"
        
        let params: [String: String] = [
            "serviceKey": apiKey,
            "cityCode": "\(cityCode)",
            "nodeNm": stationName,
            "nodeNo": arsId,
            "_type": "json",
            "numOfRows": "10",
            "pageNo": "1"
        ]
        
        print("[nodeId 조회] cityCode: \(cityCode), 정류소: \(stationName), arsId: \(arsId)")
        
        // API 요청
        request(urlString: urlString, params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(NodeIdResponse.self, from: data)
                    
                    guard response.response.header.resultCode == "00" else {
                        let error = NSError(
                            domain: "BusArrivalService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: response.response.header.resultMsg]
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    if let item = response.response.body?.items.item.first {
                        print("[nodeId 조회 성공] nodeId: \(item.nodeid)")
                        completion(.success(item.nodeid))
                    } else {
                        let error = NSError(
                            domain: "BusArrivalService",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "정류소를 찾을 수 없습니다"]
                        )
                        completion(.failure(error))
                    }
                } catch {
                    print("[nodeId 조회 실패] JSON 파싱 에러: \(error)")
                    completion(.failure(error))
                }
                
            case .failure(let error):
                print("[nodeId 조회 실패] API 에러: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // 버스 도착 정보 조회하기
    func fetchBusArrivalInfo(
        cityCode: Int,
        nodeId: String,
        completion: @escaping (Result<[BusArrivalItem], Error>) -> Void
    ) {

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
        
        request(urlString: urlString, params: params) { result in
            switch result {
            case .success(let data):
                // 원본 JSON 출력
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[도착정보 응답 원본 JSON]")
                    print(jsonString)
                }
                
                do {
                    let response = try JSONDecoder().decode(BusArrivalResponse.self, from: data)
                    
                    // 응답 코드 확인
                    guard response.response.header.resultCode == "00" else {
                        print("API 에러 코드: \(response.response.header.resultCode)")
                        print("API 에러 메시지: \(response.response.header.resultMsg)")
                        let error = NSError(
                            domain: "BusArrivalService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: response.response.header.resultMsg]
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    // body 확인
                    guard let body = response.response.body else {
                        print("[도착정보 조회] body가 없음")
                        completion(.success([]))
                        return
                    }
                    
                    // totalCount 확인
                    if body.totalCount == 0 {
                        print("[도착정보 조회] totalCount = 0 (도착 예정 버스 없음)")
                        completion(.success([]))
                        return
                    }
                    
                    // items 확인
                    guard let items = body.items else {
                        print("[도착정보 조회] items가 nil")
                        completion(.success([]))
                        return
                    }
                    
                    // 결과 반환
                    let buses = items.item
                    print("[도착정보 조회 성공] \(buses.count)개 버스 정보")
                    completion(.success(buses))
                    
                } catch {
                    print("[도착정보 조회 실패] JSON 파싱 에러: \(error)")
                    print("상세: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                
            case .failure(let error):
                print("[도착정보 조회 실패] API 에러: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // 공통 네트워크 요청 함수
    private func request(
        urlString: String,
        params: [String: String],
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        var components = URLComponents(string: urlString)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components?.url else {
            let error = NSError(
                domain: "BusArrivalService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "잘못된 URL"]
            )
            completion(.failure(error))
            return
        }
        
        print("요청 URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(
                    domain: "BusArrivalService",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "잘못된 응답"]
                )
                completion(.failure(error))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let error = NSError(
                    domain: "BusArrivalService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP 에러: \(httpResponse.statusCode)"]
                )
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(
                    domain: "BusArrivalService",
                    code: -5,
                    userInfo: [NSLocalizedDescriptionKey: "데이터 없음"]
                )
                completion(.failure(error))
                return
            }
            
            completion(.success(data))
        }.resume()
    }
}
