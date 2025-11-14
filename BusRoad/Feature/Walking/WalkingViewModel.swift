import SwiftUI
import Combine
import MapKit
import CoreLocation

final class WalkingViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - Published UI State
    @Published var bigDistanceText: String = "-- m"
    @Published var arrowBearing: CLLocationDirection = 0
    @Published var nextCards: [String] = []
    @Published var arrived: Bool = false
    @Published var showAlert: Bool = false
    @Published var showRerouteAlert: Bool = false
    @Published var showDevSheet: Bool = false
    @Published var isRerouting: Bool = false
    @Published var journey: Journey?
    @Published var journeyIndex: Int?
    @Published var showVerifyingStop: Bool = false
    @Published var manuallyArrived: Bool = false
    
    // MARK: - 내부 상태
    let loc = CLLocationManager()
    private var currentSegmentIndex: Int = 0
    var pendingDestination: CLLocationCoordinate2D?
    private var hasCalculatedRoute = false
    
    // TMAP 경로 데이터
    var tmapCoordinates: [CLLocationCoordinate2D] = []
    var tmapTotalDistance: Int = 0
    
    // 거리 임계값
    private let stepSwitchDistance: CLLocationDistance = 15
    private let arrivalDistance: CLLocationDistance = 6
    private let offRouteThreshold: CLLocationDistance = 50  // 경로이탈 25에서 50으로 증가
    
    // 오프루트 감지
    private var offRouteSince: Date? = nil
    private let offRouteDebounce: TimeInterval = 5  // 3에서 5초로 증가
    private var lastRecalcAt: Date = .distantPast
    private let recalcCooldown: TimeInterval = 60  // 30에서 60초로 증가
    
    // GPS 워밍업
    private var firstLocationTime: Date? = nil
    private let gpsWarmupTime: TimeInterval = 5
    
    // 정확도 게이트
    private let accuracyGate: CLLocationAccuracy = 50
    
    // Journey Manager
    private let journeyManager: JourneyManager
    
    // MARK: - Init
    init(journeyManager: JourneyManager = .shared) {
        self.journeyManager = journeyManager
        super.init()
        
        loc.delegate = self
        loc.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        loc.allowsBackgroundLocationUpdates = true
        loc.pausesLocationUpdatesAutomatically = false
        loc.showsBackgroundLocationIndicator = true
        loc.headingFilter = 1
        loc.headingOrientation = .portrait
        
        if let journey = journeyManager.selectedJourney,
           let index = journeyManager.journeyIndex {
            self.journey = journey
            self.journeyIndex = index
        }
    }
    
    // MARK: - Public Methods
    func start() {
        loc.requestAlwaysAuthorization()
        loc.startUpdatingLocation()
        loc.startUpdatingHeading()
    }
    
    func setDestination(_ dest: CLLocationCoordinate2D) {
        resetRouteState()
        pendingDestination = dest
        tryCalculateIfReady()
    }
    
    func setDestination(from node: WalkRouteNode) {
        let c = CLLocationCoordinate2D(
            latitude: node.end.latitude,
            longitude: node.end.longitude
        )
        setDestination(c)
    }
    
    func rerouteIfNeeded() {
        guard let origin = loc.location?.coordinate,
              let dest = pendingDestination else { return }
        
        isRerouting = true
        showRerouteAlert = false
        offRouteSince = nil
        lastRecalcAt = Date()
        
        // 도착 상태는 리셋하지 않음
        
        calculateRoute(origin: origin, dest: dest)
    }
    
    func dismissRerouteAlert() {
        showRerouteAlert = false
        lastRecalcAt = Date()
        offRouteSince = nil
    }
    
    func deferRealert(seconds: TimeInterval = 90) {
        lastRecalcAt = Date()
        offRouteSince = nil
    }
    
    // MARK: - Private Methods
    private func resetRouteState() {
        tmapCoordinates = []
        tmapTotalDistance = 0
        currentSegmentIndex = 0
        hasCalculatedRoute = false
        
        if !isRerouting {
            arrived = false
            manuallyArrived = false
            showVerifyingStop = false
        }
        
        bigDistanceText = "-- m"
        arrowBearing = 0
        nextCards = []
        showRerouteAlert = false
        offRouteSince = nil
        firstLocationTime = nil
    }
    
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
        if let totalDistance = tmapResponse.features.first?.properties.totalDistance {
            self.tmapTotalDistance = totalDistance
            self.bigDistanceText = "\(totalDistance) m"
            print("📏 TMAP 총 거리: \(totalDistance)m")
        }
        
        var allCoordinates: [CLLocationCoordinate2D] = []
        for feature in tmapResponse.features {
            for coord in feature.geometry.coordinates where coord.count >= 2 {
                let coordinate = CLLocationCoordinate2D(
                    latitude: coord[1],
                    longitude: coord[0]
                )
                allCoordinates.append(coordinate)
            }
        }
        
        self.tmapCoordinates = allCoordinates
        print("📍 좌표 \(allCoordinates.count)개 수집 완료")
        
        var cards: [String] = []
        for feature in tmapResponse.features {
            if let description = feature.properties.description,
               let distance = feature.properties.distance {
                cards.append("\(description) \(distance)m")
            }
        }
        self.nextCards = Array(cards.prefix(3))
        
        // 재탐색 완료 처리
        if isRerouting {
            isRerouting = false
            if tmapTotalDistance < 10 {
                arrived = true
                manuallyArrived = true
            }
        }
        
        ProgressLiveActivityManager.totalDistance = Double(tmapTotalDistance)
        ProgressLiveActivityManager.shared.updateWalkingActivity(
            newLeftDistance: Double(tmapTotalDistance)
        )
    }
    
    // MARK: - Apple Maps Fallback
    private func fallbackToAppleMaps(origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) {
        print("🍎 Apple Maps로 fallback")
        
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        req.transportType = .walking
        
        MKDirections(request: req).calculate { [weak self] resp, err in
            guard let self else { return }
            
            if let err = err {
                self.bigDistanceText = "경로 계산 실패"
                print("❌ Apple Maps 에러: \(err.localizedDescription)")
                self.isRerouting = false
                return
            }
            
            guard let routes = resp?.routes,
                  !routes.isEmpty,
                  let shortest = routes.min(by: { $0.distance < $1.distance }) else {
                self.bigDistanceText = "경로 없음"
                self.isRerouting = false
                return
            }
            
            let polyline = shortest.polyline
            let points = polyline.points()
            var coords: [CLLocationCoordinate2D] = []
            
            for i in 0..<polyline.pointCount {
                coords.append(points[i].coordinate)
            }
            
            self.tmapCoordinates = coords
            self.tmapTotalDistance = Int(shortest.distance)
            self.bigDistanceText = "\(Int(shortest.distance)) m"
            
            if self.isRerouting {
                self.isRerouting = false
                if self.tmapTotalDistance < 10 {
                    self.arrived = true
                    self.manuallyArrived = true
                }
            }
            
            ProgressLiveActivityManager.totalDistance = shortest.distance
            ProgressLiveActivityManager.shared.updateWalkingActivity(
                newLeftDistance: shortest.distance
            )
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
    
    // MARK: - 핵심 업데이트 로직
    private func updateWithTmapRoute(location: CLLocation, heading: CLHeading?) {
        guard !manuallyArrived else { return }
        guard !tmapCoordinates.isEmpty else {
            bigDistanceText = "-- m"
            return
        }
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy < accuracyGate else { return }
        guard !isRerouting else { return }
        
        // 1. 구간 진행
        if currentSegmentIndex < tmapCoordinates.count - 1 {
            let nextPointIndex = currentSegmentIndex + 1
            let nextPointLocation = CLLocation(
                latitude: tmapCoordinates[nextPointIndex].latitude,
                longitude: tmapCoordinates[nextPointIndex].longitude
            )
            let distanceToNext = location.distance(from: nextPointLocation)
            
            if distanceToNext < stepSwitchDistance {
                currentSegmentIndex = nextPointIndex
                print("✅ 구간 \(nextPointIndex) 통과")
            }
        }
        
        // 2. 남은 거리
        let remainDistance = calculateRemainDistance(from: location)
        bigDistanceText = "\(Int(remainDistance)) m"
        
        // 3. 도착 체크
        if remainDistance < arrivalDistance && !arrived && !manuallyArrived && !isRerouting {
            arrived = true
            print("🎯 목적지 도착!")
            ProgressLiveActivityManager.shared.updateWalkingActivity(newLeftDistance: 0)
        }
        
        // 4. 화살표 방향
        if let nextCoord = findNextCoordinate(from: location),
           let headingValue = heading?.trueHeading, headingValue >= 0 {
            let targetBearing = bearing(from: location.coordinate, to: nextCoord)
            let relative = (targetBearing - headingValue + 360)
                .truncatingRemainder(dividingBy: 360)
            arrowBearing = relative
        }
        
        // 5. 오프루트 감지
        if !arrived {
            checkOffRoute(location: location)
        }
        
        // 6. 라이브 액티비티
        if !arrived {
            ProgressLiveActivityManager.shared.updateWalkingActivity(
                newLeftDistance: remainDistance
            )
        }
    }
    
    // MARK: - 오프루트 감지
    private func checkOffRoute(location: CLLocation) {
        // GPS 워밍업 체크
        if firstLocationTime == nil {
            firstLocationTime = Date()
        }
        guard let firstTime = firstLocationTime,
              Date().timeIntervalSince(firstTime) > gpsWarmupTime else {
            return
        }
        
        // GPS 정확도가 너무 낮으면 체크 안함
        guard location.horizontalAccuracy < 20 else { return }
        guard !tmapCoordinates.isEmpty else { return }
        
        // 목적지 근처에서는 체크 안함
        if let dest = pendingDestination {
            let destLocation = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let distToDest = location.distance(from: destLocation)
            if distToDest < 100 {
                return
            }
        }
        
        var minDistance = Double.greatestFiniteMagnitude
        
        let checkStart = max(0, currentSegmentIndex - 5)
        let checkEnd = min(tmapCoordinates.count - 1, currentSegmentIndex + 10)
        
        for i in checkStart...checkEnd {
            let point = CLLocation(
                latitude: tmapCoordinates[i].latitude,
                longitude: tmapCoordinates[i].longitude
            )
            let distance = location.distance(from: point)
            minDistance = min(minDistance, distance)
        }
        
        let effectiveThreshold = offRouteThreshold + location.horizontalAccuracy
        
        if minDistance > effectiveThreshold {
            if offRouteSince == nil {
                offRouteSince = Date()
                print("⚠️ 경로 이탈 감지 시작: \(Int(minDistance))m")
            } else if let since = offRouteSince {
                let elapsed = Date().timeIntervalSince(since)
                let canShowAlert = Date().timeIntervalSince(lastRecalcAt) > recalcCooldown
                
                if elapsed > offRouteDebounce && canShowAlert && !showRerouteAlert && !isRerouting {
                    print("🔄 재탐색 알림 표시")
                    showRerouteAlert = true
                    lastRecalcAt = Date()
                }
            }
        } else {
            if offRouteSince != nil {
                print("✅ 경로로 복귀: \(Int(minDistance))m")
                offRouteSince = nil
            }
        }
    }
    
    // MARK: - 거리 계산
    private func calculateRemainDistance(from userLocation: CLLocation) -> CLLocationDistance {
        guard !tmapCoordinates.isEmpty else { return 0 }
        guard currentSegmentIndex < tmapCoordinates.count else { return 0 }
        
        let targetIndex = min(currentSegmentIndex + 1, tmapCoordinates.count - 1)
        
        let targetLocation = CLLocation(
            latitude: tmapCoordinates[targetIndex].latitude,
            longitude: tmapCoordinates[targetIndex].longitude
        )
        var remainingDistance = userLocation.distance(from: targetLocation)
        
        for i in targetIndex..<(tmapCoordinates.count - 1) {
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
        
        let minTargetDistance: CLLocationDistance = 15
        let searchStartIndex = min(currentSegmentIndex + 1, tmapCoordinates.count - 1)
        
        for i in searchStartIndex..<tmapCoordinates.count {
            let nextLocation = CLLocation(
                latitude: tmapCoordinates[i].latitude,
                longitude: tmapCoordinates[i].longitude
            )
            let distance = userLocation.distance(from: nextLocation)
            
            if distance >= minTargetDistance {
                return tmapCoordinates[i]
            }
        }
        
        return tmapCoordinates.last
    }
    
    // MARK: - Bearing 계산
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let φ1 = from.latitude * .pi/180, φ2 = to.latitude * .pi/180
        let dλ = (to.longitude - from.longitude) * .pi/180
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        let θ = atan2(y, x) * 180 / .pi
        return fmod(θ + 360, 360)
    }
}
