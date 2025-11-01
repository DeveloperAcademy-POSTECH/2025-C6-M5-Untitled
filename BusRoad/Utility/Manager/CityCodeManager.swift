import CoreLocation
import Foundation

class CityCodeManager {
    static let shared = CityCodeManager()
    
    // 도시 목록을 저장할 배열
    private var cities: [City] = []
    
    private init() {
        loadCityCodes()
    }
    
    /// 도시코드 불러오는 함수
    private func loadCityCodes() {
        guard let url = Bundle.main.url(forResource: "citycodes", withExtension: "json") else {
            print("citycodes.json 파일이 없습니다.")
            return
            
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            cities = try JSONDecoder().decode([City].self, from: data)
            
            print("도시코드 \(cities.count)개 로드 완료")
        } catch {
            print("json 파싱 실패\(error)")
        }
    }
    
    /// 도시 이름으로 cityCode 찾기
    func getCityCodeByName(cityName: String) -> Int? {
        let city = cities.first { city in
            city.cityname.contains(cityName)
        }
        
        if let found = city {
            print("도시 찾음 \(found.cityname) -> \(found.citycode)")
        } else {
            print("도시를 찾을 수 없음 \(cityName)")
        }
        
        return city?.citycode
    }
    
    
    /// 좌표로 도시찾기
    func getCityCideByLocation(
        latitude: Double,
        longitude: Double,
        completion: @escaping (Int?) -> Void
    ) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        print("좌표로 도시 검색 중: (\(latitude), \(longitude))")
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("위치 정보를 찾을 수 없습니다")
                completion(nil)
                return
            }
            
            let cityName = placemark.locality ?? ""
            print("검색된 도시: \(cityName)")
            
            let cityCode = self.getCityCodeByName(cityName: cityName)
            completion(cityCode)
        }
    }
}
