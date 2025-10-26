import Foundation
import CoreLocation

// 1. 전체 응답 (여러 구간을 담는 박스)
struct TmapPedestrianResponse: Decodable {
    let type: String  // "FeatureCollection" (고정)
    let features: [TmapFeature]  // 여러 구간들
}

// 2. 각 구간 (하나의 안내)
struct TmapFeature: Decodable {
    let type: String  // "Feature" (고정)
    let geometry: TmapGeometry  // 좌표 정보
    let properties: TmapProperties  // 안내 정보
}

// 3. 좌표 정보
struct TmapGeometry: Decodable {
    let type: String  // "LineString" 또는 "Point"
    let coordinates: [[Double]]  // 통일된 형태로 저장
    
    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }
    
    // 디코딩
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        if type == "Point" {
            // Point: [경도, 위도] → [[경도, 위도]]로 변환
            let singleCoord = try container.decode([Double].self, forKey: .coordinates)
            coordinates = [singleCoord]
        } else {
            // LineString: [[경도, 위도], ...] 그대로
            coordinates = try container.decode([[Double]].self, forKey: .coordinates)
        }
    }
}

// 4. 안내 정보
struct TmapProperties: Decodable {
    let totalDistance: Int?  // 총 거리 (미터)
    let totalTime: Int?      // 총 시간 (초)
    let index: Int?          // 몇 번째 구간?
    let description: String? // "직진", "좌회전" 같은 안내
    let distance: Int?       // 이 구간 거리
}
