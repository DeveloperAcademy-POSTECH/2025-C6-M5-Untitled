import SwiftUI
import Combine
import MapKit
import CoreLocation
import AVFoundation
import AudioToolbox

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
    @Published var manuallyArrived: Bool = false
    @Published var showArrivalContent = false
    @Published var finishedOnboarding: Bool = true
    
    // MARK: - 내부 상태
    let loc = CLLocationManager()
    private var currentSegmentIndex: Int = 0
    var pendingDestination: CLLocationCoordinate2D?
    private var hasCalculatedRoute = false
    private var lastArrowBearing: CLLocationDirection = 0
    private let arrowBearingThreshold: Double = 10
    private var navigationStartTime: Date? = nil
    private var isRouteApplied: Bool = false
    
    // TMAP 경로 데이터
    var tmapCoordinates: [CLLocationCoordinate2D] = []
    var tmapTotalDistance: Int = 0
    
    // 거리 임계값
    private let stepSwitchDistance: CLLocationDistance = 3 // 다음 좌표까지 ?m 이내이면 해당 점을 "지나간 것으로 판단"
    private var arrivalDistance: CLLocationDistance = 12
    private let offRouteThreshold: CLLocationDistance = 50
    
    // 오프루트 감지
    private var offRouteSince: Date? = nil
    private let offRouteDebounce: TimeInterval = 5
    private var lastRecalcAt: Date = .distantPast
    private let recalcCooldown: TimeInterval = 60
    
    // GPS 워밍업
    private var firstLocationTime: Date? = nil
    private let gpsWarmupTime: TimeInterval = 5
    
    // 정확도 게이트
    private let accuracyGate: CLLocationAccuracy = 50
    
    // 음성 안내
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var hasAnnouncedStart: Bool = false // 시작 안내
    
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
            
            if index == journey.nodes.count - 1 {
                arrivalDistance = 6
            } else {
                arrivalDistance = 12
            }
        }
        
        configureAudioSession()
    }
    
    // MARK: - Public Methods
    func start() {
        loc.requestAlwaysAuthorization()
        loc.startUpdatingLocation()
        loc.startUpdatingHeading()
    }
    
    func setDestination(_ dest: CLLocationCoordinate2D) {
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
        
        currentSegmentIndex = 0
        stopAllAnnouncements()
        isRerouting = true
        showRerouteAlert = false
        offRouteSince = nil
        lastRecalcAt = Date()
        
        calculateRoute(origin: origin, dest: dest)
    }
    
    func dismissRerouteAlert() {
        stopAllAnnouncements()
        showRerouteAlert = false
        lastRecalcAt = Date()
        offRouteSince = nil
    }
    
    func deferRealert(seconds: TimeInterval = 90) {
        lastRecalcAt = Date()
        offRouteSince = nil
    }
    
    
    // 음성 중단
    func stopAllAnnouncements() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.speechSynthesizer.isSpeaking {
                self.speechSynthesizer.stopSpeaking(at: .immediate)
                print("🔇 음성 안내 중단")
            }
        }
    }
    // MARK: - Private Methods
    private func resetRouteState() {
        tmapCoordinates = []
        tmapTotalDistance = 0
        currentSegmentIndex = 0
        hasCalculatedRoute = false
        hasAnnouncedStart = false
        
        if !isRerouting {
            arrived = false
            manuallyArrived = false
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
        self.currentSegmentIndex = 0
        print("📍 좌표 \(allCoordinates.count)개 수집 완료")
        print("좌표\(allCoordinates)")
        print("🗺️ === TMAP 안내 정보 ===")
        for (index, feature) in tmapResponse.features.enumerated() {
            if let desc = feature.properties.index,
               let dist = feature.properties.distance {
                print("[\(index)] \(desc) - \(dist)m")
            }
        }
        print("========================")
        
        var cards: [String] = []
        for feature in tmapResponse.features {
            if let description = feature.properties.description,
               let distance = feature.properties.distance {
                cards.append("\(description) \(distance)m")
            }
        }
        self.nextCards = Array(cards.prefix(3))
        
        self.isRouteApplied = true
        self.isRerouting = false
        
        self.tryAnnounceStart()
        
        ProgressLiveActivityManager.totalDistance = Double(tmapTotalDistance)
        ProgressLiveActivityManager.shared.updateWalkingActivity(
            newLeftDistance: Double(tmapTotalDistance)
        )
        
        if !hasAnnouncedStart && !isRerouting && finishedOnboarding {
            announceStart()
            hasAnnouncedStart = true
        }
    }
    
    // MARK: - 안내 시작음
    func tryAnnounceStart() {
            guard !hasAnnouncedStart,
                  isRouteApplied,
                  finishedOnboarding,
                  !isRerouting else {
                return
            }
            
            // 모든 조건 충족 시 안내
            announceStart()
            hasAnnouncedStart = true
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
        guard finishedOnboarding else {return}
        
        //재탐색 알림이나 도착알림 표시 중이면 음성안내 방지
        guard !showRerouteAlert && !showAlert else { return }
        
        // 구간 진행 - 점 뛰어넘기
        advanceSegment(from: location) // 점 이동했는지 확인하고 업데이트하기
        
        // 남은 거리
        let remainDistance = calculateRemainDistance(from: location)
        bigDistanceText = "\(Int(remainDistance)) m"
        
        // 도착 체크
        if remainDistance < arrivalDistance && !arrived && !manuallyArrived && !isRerouting {
            stopAllAnnouncements()
            arrived = true
            print("목적지 도착!")
            ProgressLiveActivityManager.shared.updateWalkingActivity(newLeftDistance: 0)
        }
        
        // 화살표 방향
        if let nextCoord = findNextCoordinate(from: location),
           let headingValue = heading?.trueHeading, headingValue >= 0 {
            let targetBearing = bearing(from: location.coordinate, to: nextCoord)
            let relative = (targetBearing - headingValue + 360)
                .truncatingRemainder(dividingBy: 360)
            updateArrowBearingSmooth(newBearing: relative)
        }
        
        // 오프루트 감지
        if !arrived {
            checkOffRoute(location: location)
        }
        
        // 라이브 액티비티
        if !arrived {
            ProgressLiveActivityManager.shared.updateWalkingActivity(
                newLeftDistance: remainDistance
            )
        }
    }
    
    // MARK: - 점 뛰어넘기
    private func advanceSegment(from location: CLLocation) {
        
        currentSegmentIndex = max(0, min(currentSegmentIndex, tmapCoordinates.count - 1))

        let checkRange = min(10, tmapCoordinates.count - currentSegmentIndex - 1)
        guard checkRange > 0 else { return }
                
        var closestIndex = currentSegmentIndex
        var closestDistance = Double.greatestFiniteMagnitude
        
        // 현재부터 앞으로 10개 점까지 확인
        for i in currentSegmentIndex..<min(currentSegmentIndex + checkRange, tmapCoordinates.count) {
            let pointLocation = CLLocation(
                latitude: tmapCoordinates[i].latitude,
                longitude: tmapCoordinates[i].longitude
            )
            let distance = location.distance(from: pointLocation)
            
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = i
            }
        }
        
        // 가장 가까운 점이 현재보다 앞에 있으면 그 점으로 이동
        if closestIndex > currentSegmentIndex {
            let jumped = closestIndex - currentSegmentIndex
            print("구간 \(currentSegmentIndex) → \(closestIndex) (건너뛴 점: \(jumped)개, 거리: \(Int(closestDistance))m)")
            currentSegmentIndex = closestIndex
        }
        // 아니면 기존처럼 다음 점만 체크
        else if currentSegmentIndex < tmapCoordinates.count - 1 {
            let nextPointIndex = currentSegmentIndex + 1
            let nextPointLocation = CLLocation(
                latitude: tmapCoordinates[nextPointIndex].latitude,
                longitude: tmapCoordinates[nextPointIndex].longitude
            )
            let distanceToNext = location.distance(from: nextPointLocation)
            
            if distanceToNext < stepSwitchDistance {
                currentSegmentIndex = nextPointIndex
                print("구간 \(nextPointIndex) 통과")
            }
        }
    }
    
    // MARK: - 오프루트 감지
    private func checkOffRoute(location: CLLocation) {
        
        if firstLocationTime == nil {
            firstLocationTime = Date()
        }
        guard let firstTime = firstLocationTime,
              Date().timeIntervalSince(firstTime) > gpsWarmupTime else {
            return
        }
        
        guard location.horizontalAccuracy < 20 else { return }
        guard !tmapCoordinates.isEmpty else { return }
        
        if let dest = pendingDestination {
            let destLocation = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let distToDest = location.distance(from: destLocation)
            if distToDest < 20 {
                return
            }
        }
        
        var minDistance = Double.greatestFiniteMagnitude
        
        let checkStart = max(0, min(currentSegmentIndex - 5, tmapCoordinates.count - 1))
        let checkEnd = min(tmapCoordinates.count - 1, max(0, currentSegmentIndex + 10))
        
        guard checkStart <= checkEnd else { return }
        
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
                    stopAllAnnouncements()
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
    
    private func announceStart() {
        
        navigationStartTime = Date()
        
        AudioServicesPlayAlertSound(1110) // 1110

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
                        
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let text = "도보 길 안내를 시작합니다"
                
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
                utterance.rate = 0.5
                utterance.volume = 1.0
                
                self.speechSynthesizer.speak(utterance)
                
                print("🔊 시작 안내: \(text)")
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
        
        let minTargetDistance: CLLocationDistance = 15  // 15m로 변경
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
    
    // MARK: - 화살표 부드럽게 업데이트
    private func updateArrowBearingSmooth(newBearing: CLLocationDirection) {
        // 처음이면 바로 설정
        if lastArrowBearing == 0 {
            arrowBearing = newBearing
            lastArrowBearing = newBearing
            return
        }
        
        // 각도 차이 계산
        var diff = newBearing - lastArrowBearing
        
        // 360도 넘어가는 경우 처리
        if diff > 180 {
            diff -= 360
        } else if diff < -180 {
            diff += 360
        }
        
        let absDiff = abs(diff)
        
        // 10도 이하 변화는 무시
        if absDiff < arrowBearingThreshold {
            return
        }
        
        // 10도 이상 변화만 업데이트
//        withAnimation(.easeInOut(duration: 0.3)) {
            arrowBearing = newBearing
//        }
        lastArrowBearing = newBearing
    }
    
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .mixWithOthers]
            )
            
            try audioSession.setActive(true)
            
            print("✅ 오디오 세션 설정 완료")
            
        } catch {
            print("❌ 오디오 세션 설정 실패: \(error.localizedDescription)")
        }
    }
}
