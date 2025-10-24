import SwiftUI
import Combine
import MapKit
import CoreLocation

// TODO: 나중에 기능 분리하기(service)
final class WalkingViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - UI 상태
    @Published var bigDistanceText: String = "-- m"
    @Published var arrowBearing: CLLocationDirection = 0
    @Published var nextCards: [String] = []
    @Published var arrived: Bool = false
    
    // MARK: - 내부 상태
    let loc = CLLocationManager()
    private var stepIndex: Int = 0
    var pendingDestination: CLLocationCoordinate2D?
    private var hasCalculatedRoute = false
    
    // TMAP 경로 데이터 저장
    var tmapCoordinates: [CLLocationCoordinate2D] = []
    private var tmapTotalDistance: Int = 0
    
    private var stepSwitchDistance: CLLocationDistance = 6
    
    override init() {
        super.init()
        loc.delegate = self
        loc.desiredAccuracy = kCLLocationAccuracyBest
        loc.headingFilter = 1
        loc.headingOrientation = .portrait
    }
    
    // MARK: - Public
    func start() {
        loc.requestWhenInUseAuthorization()
        loc.startUpdatingLocation()
        loc.startUpdatingHeading()
    }
    
    func setDestination(_ dest: CLLocationCoordinate2D) {
        resetRouteState()
        pendingDestination = dest
        tryCalculateIfReady()
    }
    
    func setDestination(from node: WalkRouteNode) {
        let c = CLLocationCoordinate2D(latitude: node.end.latitude, longitude: node.end.longitude)
        setDestination(c)
    }
    
    private func resetRouteState() {
        tmapCoordinates = []
        tmapTotalDistance = 0
        stepIndex = 0
        hasCalculatedRoute = false
        arrived = false
        bigDistanceText = "-- m"
        arrowBearing = 0
        nextCards = []
    }
    
    // MARK: - Route Calculation
    private func tryCalculateIfReady() {
        guard !hasCalculatedRoute,
              let origin = loc.location?.coordinate,
              let dest = pendingDestination else { return }
        hasCalculatedRoute = true
        calculateRoute(origin: origin, dest: dest)
    }
    
    private func calculateRoute(origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) {
        let tmapService = TmapService()
        
        Task {
            do {
                print("🚶 TMAP 경로 계산 시작")
                let tmapResponse = try await tmapService.getPedestrianRoute(from: origin, to: dest)
                
                await MainActor.run {
                    self.applyTmapRoute(tmapResponse)
                }
                
            } catch {
                print("❌ TMAP 에러: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.fallbackToAppleMaps(origin: origin, dest: dest)
                }
            }
        }
    }
    
    // MARK: - TMAP 경로 적용
    private func applyTmapRoute(_ tmapResponse: TmapPedestrianResponse) {
        // 1. 총 거리 저장
        if let totalDistance = tmapResponse.features.first?.properties.totalDistance {
            self.tmapTotalDistance = totalDistance
            self.bigDistanceText = "\(totalDistance) m"
            print("TMAP 총 거리: \(totalDistance)m")
        }
        
        // 2. 모든 좌표 모으기
        var allCoordinates: [CLLocationCoordinate2D] = []
        
        for feature in tmapResponse.features {
            let coords = feature.geometry.coordinates
                for coord in coords {
                    if coord.count >= 2 {
                        let coordinate = CLLocationCoordinate2D(
                            latitude: coord[1],   // 위도
                            longitude: coord[0]   // 경도
                        )
                        allCoordinates.append(coordinate)
                }
            }
        }
        
        self.tmapCoordinates = allCoordinates
        print("좌표 \(allCoordinates.count)개 수집 완료")
        
        // 3. 안내 카드 만들기
        var cards: [String] = []
        for feature in tmapResponse.features {
            if let description = feature.properties.description,
               let distance = feature.properties.distance {
                cards.append("\(description) \(distance)m")
            }
        }
        self.nextCards = Array(cards.prefix(3))
        print("안내 카드: \(nextCards)")
    }
    
    // MARK: - Apple Maps Fallback
    private func fallbackToAppleMaps(origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) {
        print("⚠️ Apple Maps로 fallback")
        
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        req.transportType = .walking
        
        MKDirections(request: req).calculate { [weak self] resp, err in
            guard let self else { return }
            if let err = err {
                self.bigDistanceText = "경로 계산 실패"
                print("Apple Maps 에러: \(err.localizedDescription)")
                return
            }
            
            guard let routes = resp?.routes, !routes.isEmpty else {
                self.bigDistanceText = "경로 없음"
                return
            }
            
            guard let shortest = routes.min(by: { $0.distance < $1.distance }) else {
                self.bigDistanceText = "경로 없음"
                return
            }
            
            print("Apple Maps 경로: \(Int(shortest.distance))m")
            
            // Apple Maps 좌표로 변환
            let polyline = shortest.polyline
            let points = polyline.points()
            var coords: [CLLocationCoordinate2D] = []
            
            for i in 0..<polyline.pointCount {
                coords.append(points[i].coordinate)
            }
            
            self.tmapCoordinates = coords
            self.tmapTotalDistance = Int(shortest.distance)
            self.bigDistanceText = "\(Int(shortest.distance)) m"
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways ||
            manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
            tryCalculateIfReady()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if let loc = manager.location {
            updateWithTmapRoute(location: loc, heading: newHeading)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        tryCalculateIfReady()
        updateWithTmapRoute(location: last, heading: manager.heading)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    // MARK: - TMAP 경로 기반 위치 업데이트
    private func updateWithTmapRoute(location: CLLocation, heading: CLHeading?) {
        guard !tmapCoordinates.isEmpty else {
            bigDistanceText = "-- m"
            return
        }
        guard location.horizontalAccuracy < 50 else { return }
        
        // 1. 남은 거리 계산
        let remainDistance = calculateRemainDistance(from: location)
        bigDistanceText = "\(Int(remainDistance)) m"
        
        // 2. 도착 체크
        if remainDistance < stepSwitchDistance {
            arrived = true
            print("목적지 도착!")
        }
        
        // 3. 화살표 방향 계산
        if let nextCoord = findNextCoordinate(from: location),
           let headingValue = heading?.trueHeading, headingValue >= 0 {
            let targetBearing = bearing(from: location.coordinate, to: nextCoord)
            let relative = (targetBearing - headingValue + 360)
                .truncatingRemainder(dividingBy: 360)
            arrowBearing = relative
        }
    }
    
    // MARK: - TMAP 거리 계산
    private func calculateRemainDistance(from userLocation: CLLocation) -> CLLocationDistance {
        guard !tmapCoordinates.isEmpty else { return 0 }
        
        // 가장 가까운 경로상의 점 찾기
        var minDistance = CLLocationDistance.greatestFiniteMagnitude
        var closestIndex = 0
        
        for (index, coord) in tmapCoordinates.enumerated() {
            let pointLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = userLocation.distance(from: pointLocation)
            
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }
        
        // 남은 경로 거리 계산
        var remainingDistance: CLLocationDistance = 0
        
        for i in closestIndex..<(tmapCoordinates.count - 1) {
            let from = CLLocation(
                latitude: tmapCoordinates[i].latitude,
                longitude: tmapCoordinates[i].longitude
            )
            let to = CLLocation(
                latitude: tmapCoordinates[i + 1].latitude,
                longitude: tmapCoordinates[i + 1].longitude
            )
            remainingDistance += from.distance(from: to)
        }
        
        return remainingDistance
    }
    
    // MARK: - 다음 좌표 찾기
    private func findNextCoordinate(from userLocation: CLLocation) -> CLLocationCoordinate2D? {
        guard !tmapCoordinates.isEmpty else { return nil }
        
        var minDistance = CLLocationDistance.greatestFiniteMagnitude
        var closestIndex = 0
        
        for (index, coord) in tmapCoordinates.enumerated() {
            let pointLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = userLocation.distance(from: pointLocation)
            
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }
        
        // 다음 좌표 반환 (최소 10m 이상 떨어진 점)
        for i in (closestIndex + 1)..<tmapCoordinates.count {
            let nextLocation = CLLocation(
                latitude: tmapCoordinates[i].latitude,
                longitude: tmapCoordinates[i].longitude
            )
            if userLocation.distance(from: nextLocation) > 10 {
                return tmapCoordinates[i]
            }
        }
        
        return tmapCoordinates.last
    }
    
    // MARK: - Geometry Helpers
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let φ1 = from.latitude * .pi/180, φ2 = to.latitude * .pi/180
        let dλ = (to.longitude - from.longitude) * .pi/180
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        let θ = atan2(y, x) * 180 / .pi
        return fmod(θ + 360, 360)
    }
}
