import Foundation


protocol BusServiceType {
    // nodeId를 가져오는 함수
    func fetchNodeId(cityCode: Int, stationName: String, arsId: String?) async throws -> String
    
    // 버스 도착 정보를 가져오는 함수
    func fetchBusArrivalInfo(cityCode: Int, nodeId: String) async throws -> [BusArrivalItem]
}
