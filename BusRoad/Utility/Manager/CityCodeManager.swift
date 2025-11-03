import CoreLocation
import Foundation

class CityCodeManager {
    static let shared = CityCodeManager()
    
    private var cities: [City] = []
    
    private init() {
        loadCityCodes()
    }
    
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
    
    // 도시 이름으로 도시코드 찾기
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
    
    // 좌표로 도시코드 찾기
    func getCityCodeByLocationAsync(latitude: Double, longitude: Double) async -> Int? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        print("좌표로 도시 검색 중: (\(latitude), \(longitude))")
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                print("위치 정보를 찾을 수 없습니다")
                return nil
            }
            
            let cityName = placemark.locality ?? ""
            print("검색된 도시: \(cityName)")
            
            let cityCode = getCityCodeByName(cityName: cityName)
            return cityCode
        } catch {
            print("Geocoding 실패: \(error.localizedDescription)")
            return nil
        }
    }
}
