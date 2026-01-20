import Foundation

struct BusRouteInfo {
    let routeId: String // 노선 ID
    let busName: String // 버스 번호
    let ord: Int        // 순번
    let stId: String    // 정류소 고유번호 (Node ID)
    let arsId: String   // ARS ID
    let stationName: String
}

class BusDataManager {
    static let shared = BusDataManager()

    // 이름 기반
    private var busInfoByName: [String: [BusRouteInfo]] = [:]
    
    // stId(NODE_ID) 기반
    private var busInfoByStId: [String: [BusRouteInfo]] = [:]

    private init() { loadCSV() }

    private func normalizeName(_ text: String) -> String {
        text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "/", with: "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeBus(_ busName: String) -> String {
        busName
            .replacingOccurrences(of: "번", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadCSV() {
        guard let path = Bundle.main.path(forResource: "SeoulBusInformation", ofType: "csv") else { return }

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let rows = content.components(separatedBy: "\n")

            for (index, row) in rows.enumerated() where index > 0 {
                let columns = row.components(separatedBy: ",")
                if columns.count >= 6 {
                    let routeId = columns[0].trimmingCharacters(in: .whitespaces)
                    let busName = columns[1].trimmingCharacters(in: .whitespaces)
                    let ordString = columns[2].trimmingCharacters(in: .whitespaces)
                    let stId = columns[3].trimmingCharacters(in: .whitespaces)   // NODE_ID(stId)
                    let arsId = columns[4].trimmingCharacters(in: .whitespaces)
                    let stationName = columns[5].trimmingCharacters(in: .whitespaces)

                    if let ord = Int(ordString) {
                        let info = BusRouteInfo(
                            routeId: routeId,
                            busName: busName,
                            ord: ord,
                            stId: stId,
                            arsId: arsId,
                            stationName: stationName
                        )

                        // 이름 인덱스
                        let cleanName = normalizeName(stationName)
                        busInfoByName[cleanName, default: []].append(info)

                        // stId 인덱스
                        busInfoByStId[stId, default: []].append(info)
                    }
                }
            }
        } catch {
            print("CSV Error: \(error)")
        }
    }

    // 핵심: stId + stationName 같이 보고 busName까지 매칭해서 하나를 뽑기
    func findTargetRouteInfo(stId: String?, stationName: String, busName: String) -> BusRouteInfo? {
        let cleanBus = normalizeBus(busName)
        let cleanStation = normalizeName(stationName)

        // 1) stId로 먼저 후보 좁히기
        if let stId, let candidates = busInfoByStId[stId] {
            // 정류장명까지 같이 확인
            if let match = candidates.first(where: { $0.busName == cleanBus }) {
                return match
            }
        }

        // 2) stId로 못 찾으면 기존 이름 기반 fallback
        if let routes = busInfoByName[cleanStation] {
            return routes.first { $0.busName == cleanBus }
        }

        return nil
    }

    // 정류장 이름만으로 검색 
    func findTargetRouteInfoByName(stationName: String, busName: String) -> BusRouteInfo? {
        return findTargetRouteInfo(stId: nil, stationName: stationName, busName: busName)
    }
}

