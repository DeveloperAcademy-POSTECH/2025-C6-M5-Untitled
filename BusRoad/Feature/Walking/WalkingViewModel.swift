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
    
    // 현재 세그먼트 내에서의 진행률 (0.0 ~ 1.0)
    private var currentSegmentProgress: Double = 0.0
    // 현재 경로 선상에 투영된 좌표 (UI 표시 및 오차 계산용)
    private var projectedLocation: CLLocationCoordinate2D?
    
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
    private var arrivalDistance: CLLocationDistance = 12
    private let offRouteThreshold: CLLocationDistance = 50
    
    // 오프루트 감지
    private var offRouteSince: Date? = nil
    private let offRouteDebounce: TimeInterval = 8 // 5초 -> 8초
    private var lastRecalcAt: Date = .distantPast
    private let recalcCooldown: TimeInterval = 60
    
    // GPS 워밍업
    private var firstLocationTime: Date? = nil
    private let gpsWarmupTime: TimeInterval = 5
    
    // 정확도 게이트
    private let accuracyGate: CLLocationAccuracy = 60
    
    // 음성 안내 관련 변수
    private var announcedTurnIndices: Set<Int> = []
    private var lastAnnouncementTime: Date? = nil
    private let announcementCooldown: TimeInterval = 4.0 // 안내 쿨타임 4초
    
    // 회전
    private let turnAngleThreshold: Double = 30// 각도 30도
    private let announcementDistance: CLLocationDistance = 20 // 20m 이내일 때만
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var hasAnnouncedStart: Bool = false
    private var lastAnnouncedDirection: TurnDirection? = nil
    private var lastAnnouncedLocation: CLLocationCoordinate2D? = nil
    private let duplicateAnnouncementDistance: CLLocationDistance = 10.0
    
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
        
        currentSegmentIndex = 0
        currentSegmentProgress = 0.0
        stopAllAnnouncements()
        isRerouting = true
        showRerouteAlert = false
        offRouteSince = nil
        lastRecalcAt = Date()
        announcedTurnIndices.removeAll() // 재탐색 시 안내 기록 초기화
        lastAnnouncementTime = nil
        lastAnnouncedDirection = nil
        lastAnnouncedLocation = nil
        
        
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
        currentSegmentProgress = 0.0
        projectedLocation = nil
        hasCalculatedRoute = false
        announcedTurnIndices.removeAll() // 초기화
        hasAnnouncedStart = false
        lastAnnouncementTime = nil
        lastAnnouncedDirection = nil
        lastAnnouncedLocation = nil
        
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
        self.currentSegmentProgress = 0.0
        print("📍 좌표 \(allCoordinates.count)개 수집 완료")
        
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
        guard tmapCoordinates.count >= 2 else {
            bigDistanceText = "-- m"
            return
        }
        
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy < accuracyGate else { return }
        
        guard !isRerouting else { return }
        guard finishedOnboarding else { return }
        
        guard !showRerouteAlert && !showAlert else { return }
        
        // 1. 선분 기반 위치 매칭
        let matchingResult = updateCurrentSegment(location: location)
        
        // 2. 남은 거리 계산
        let remainDistance = calculateRemainDistance(
            fromSegmentIndex: currentSegmentIndex,
            progress: currentSegmentProgress,
            projectedPoint: projectedLocation ?? location.coordinate
        )
        bigDistanceText = "\(Int(remainDistance)) m"
        
        // 3. 도착 체크
        if remainDistance < arrivalDistance && !arrived && !manuallyArrived && !isRerouting {
            stopAllAnnouncements()
            arrived = true
            print("🎉 목적지 도착!")
            ProgressLiveActivityManager.shared.updateWalkingActivity(newLeftDistance: 0)
        }
        
        // 4. 화살표 업데이트 (Look-Ahead)
        if let lookAheadCoord = getLookAheadCoordinate(
            from: currentSegmentIndex,
            projectedT: currentSegmentProgress,
            meters: 15.0
        ), let headingValue = heading?.trueHeading, headingValue >= 0 {
            
            let targetBearing = bearing(from: location.coordinate, to: lookAheadCoord)
            let relative = (targetBearing - headingValue + 360).truncatingRemainder(dividingBy: 360)
            updateArrowBearingSmooth(newBearing: relative)
        }
        
        // 5. 오프루트 감지
        if !arrived {
            checkOffRoute(distanceFromPath: matchingResult.distance, accuracy: location.horizontalAccuracy)
        }
        
        // 6. 라이브 액티비티
        if !arrived {
            ProgressLiveActivityManager.shared.updateWalkingActivity(
                newLeftDistance: remainDistance
            )
        }
        
        // 7. 음성 안내
        checkForUpcomingTurn(from: location)
    }
    
    // MARK: - 선분 투영 매칭 로직
    private func updateCurrentSegment(location: CLLocation) -> (distance: CLLocationDistance, coordinate: CLLocationCoordinate2D) {
        
        let searchStart = max(0, currentSegmentIndex - 2)
        let searchEnd = min(tmapCoordinates.count - 2, currentSegmentIndex + 10)
        
        var bestIndex = currentSegmentIndex
        var minProjDistance = Double.greatestFiniteMagnitude
        var bestT: Double = 0.0
        var bestCoordinate = tmapCoordinates[currentSegmentIndex]
        
        for i in searchStart...searchEnd {
            let startNode = tmapCoordinates[i]
            let endNode = tmapCoordinates[i+1]
            
            let result = getProjectedPoint(
                location: location.coordinate,
                start: startNode,
                end: endNode
            )
            
            // 진행 방향 가중치
            let progressWeight = (i < currentSegmentIndex) ? 5.0 : 0.0
            let weightedDistance = result.distance + progressWeight
            
            if weightedDistance < minProjDistance {
                minProjDistance = weightedDistance
                bestIndex = i
                bestT = result.t
                bestCoordinate = result.coordinate
            }
        }
        
        // 너무 멀어지면 인덱스 업데이트 안함 (오프루트 처리를 위해)
        if minProjDistance < offRouteThreshold + 20 {
            self.currentSegmentIndex = bestIndex
            self.currentSegmentProgress = bestT
            self.projectedLocation = bestCoordinate
        }
        
        return (minProjDistance, bestCoordinate)
    }
    
    // MARK: - 수학적 투영 계산
    private func getProjectedPoint(
        location: CLLocationCoordinate2D,
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> (coordinate: CLLocationCoordinate2D, t: Double, distance: CLLocationDistance) {
        
        let p = MKMapPoint(location)
        let a = MKMapPoint(start)
        let b = MKMapPoint(end)
        
        let dx = b.x - a.x
        let dy = b.y - a.y
        
        if dx == 0 && dy == 0 {
            return (start, 0, location.distance(from: start))
        }
        
        let t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)
        let clampedT = max(0, min(1, t))
        
        let projX = a.x + clampedT * dx
        let projY = a.y + clampedT * dy
        let projectedMapPoint = MKMapPoint(x: projX, y: projY)
        let projectedCoord = projectedMapPoint.coordinate
        
        let dist = location.distance(from: projectedCoord)
        
        return (projectedCoord, clampedT, dist)
    }
    
    // MARK: - Look-Ahead 좌표 계산
    private func getLookAheadCoordinate(
        from currentIdx: Int,
        projectedT: Double,
        meters: Double
    ) -> CLLocationCoordinate2D? {
        
        guard tmapCoordinates.count > 1 else { return nil }
        
        var remainingMeters = meters
        
        let currentStart = tmapCoordinates[currentIdx]
        let nextIdx = min(currentIdx + 1, tmapCoordinates.count - 1)
        let currentEnd = tmapCoordinates[nextIdx]
        
        let segDist = CLLocation(latitude: currentStart.latitude, longitude: currentStart.longitude)
            .distance(from: CLLocation(latitude: currentEnd.latitude, longitude: currentEnd.longitude))
        
        let distOnCurrentSeg = segDist * (1.0 - projectedT)
        
        if distOnCurrentSeg > remainingMeters {
            let newT = projectedT + (remainingMeters / segDist)
            return interpolate(from: currentStart, to: currentEnd, t: newT)
        }
        
        remainingMeters -= distOnCurrentSeg
        
        for i in (currentIdx + 1)..<(tmapCoordinates.count - 1) {
            let start = tmapCoordinates[i]
            let end = tmapCoordinates[i+1]
            let dist = CLLocation(latitude: start.latitude, longitude: start.longitude)
                .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
            
            if dist > remainingMeters {
                let t = remainingMeters / dist
                return interpolate(from: start, to: end, t: t)
            }
            
            remainingMeters -= dist
        }
        
        return tmapCoordinates.last
    }
    
    private func interpolate(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        let lat = from.latitude + (to.latitude - from.latitude) * t
        let lon = from.longitude + (to.longitude - from.longitude) * t
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - 오프루트 감지
    private func checkOffRoute(distanceFromPath: CLLocationDistance, accuracy: CLLocationAccuracy) {
        
        if firstLocationTime == nil {
            firstLocationTime = Date()
        }
        guard let firstTime = firstLocationTime,
              Date().timeIntervalSince(firstTime) > gpsWarmupTime else {
            return
        }
        
        // [수정] GPS 정확도가 매우 나쁘면(30m 이상 오차) 경로 이탈 판정 보류 (안정성 확보)
        if accuracy > 30 { return }
        
        if let dest = pendingDestination {
            let lastPoint = tmapCoordinates.last ?? dest
            let distToDest = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
                .distance(from: CLLocation(latitude: projectedLocation?.latitude ?? lastPoint.latitude, longitude: projectedLocation?.longitude ?? lastPoint.longitude))
            
            if distToDest < 12 { return }
        }
        
        if distanceFromPath > offRouteThreshold {
            if offRouteSince == nil {
                offRouteSince = Date()
                print("⚠️ 경로 이탈 감지 시작: \(Int(distanceFromPath))m")
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
                print("✅ 경로로 복귀")
                offRouteSince = nil
            }
        }
    }
    
    // MARK: - 음성 안내
    private func checkForUpcomingTurn(from location: CLLocation) {
        guard !showRerouteAlert && !showAlert else {
            stopAllAnnouncements()
            return
        }
        
        guard tmapCoordinates.count >= 2 else { return }
        
        if let startTime = navigationStartTime, Date().timeIntervalSince(startTime) < 3.0 {
            return
        }
        
        if let lastTime = lastAnnouncementTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < announcementCooldown {
                return
            }
        }
        
        let remainingDist = calculateRemainDistance(
            fromSegmentIndex: currentSegmentIndex,
            progress: currentSegmentProgress,
            projectedPoint: projectedLocation ?? location.coordinate
        )
        
        if remainingDist < 25 {
            return
        }
        
        announcedTurnIndices = announcedTurnIndices.filter { $0 > currentSegmentIndex }
        
        let maxLookAheadDistance: CLLocationDistance = 20.0
        var accumulatedDistance: CLLocationDistance = 0.0
        
        let searchStart = currentSegmentIndex + 1
        let searchEnd = min(currentSegmentIndex + 30, tmapCoordinates.count - 1)
        
        guard searchStart < searchEnd else { return }
        
        if currentSegmentIndex < tmapCoordinates.count - 1 {
            let segStart = CLLocation(
                latitude: tmapCoordinates[currentSegmentIndex].latitude,
                longitude: tmapCoordinates[currentSegmentIndex].longitude
            )
            let segEnd = CLLocation(
                latitude: tmapCoordinates[currentSegmentIndex + 1].latitude,
                longitude: tmapCoordinates[currentSegmentIndex + 1].longitude
            )
            let segmentLength = segStart.distance(from: segEnd)
            accumulatedDistance = segmentLength * (1.0 - currentSegmentProgress)
        }
        
        for i in searchStart..<searchEnd {
            if accumulatedDistance > maxLookAheadDistance {
                break
            }
            
            if announcedTurnIndices.contains(i) {
                if i < tmapCoordinates.count - 1 {
                    let curr = CLLocation(
                        latitude: tmapCoordinates[i].latitude,
                        longitude: tmapCoordinates[i].longitude
                    )
                    let next = CLLocation(
                        latitude: tmapCoordinates[i + 1].latitude,
                        longitude: tmapCoordinates[i + 1].longitude
                    )
                    accumulatedDistance += curr.distance(from: next)
                }
                continue
            }
            
            let checkPoint = CLLocation(
                latitude: tmapCoordinates[i].latitude,
                longitude: tmapCoordinates[i].longitude
            )
            let distToPoint = location.distance(from: checkPoint)
            
            if distToPoint <= announcementDistance && finishedOnboarding {
                
                if let turn = detectTurn(at: i) {
                    
                    // 같은 방향 + 1m 이내 중복 체크
                    if let lastDir = lastAnnouncedDirection,
                       let lastLoc = lastAnnouncedLocation,
                       lastDir == turn {
                        
                        let distFromLastAnnouncement = location.distance(from: CLLocation(
                            latitude: lastLoc.latitude,
                            longitude: lastLoc.longitude
                        ))
                        
                        if distFromLastAnnouncement < duplicateAnnouncementDistance {
                            print("⏭️ 같은 방향 중복 방지: \(turn.korean), \(String(format: "%.1f", distFromLastAnnouncement))m 전 안내함")
                            
                            // 인덱스는 기록 (다음에 또 체크 안 되게)
                            announcedTurnIndices.insert(i)
                            
                            if i < tmapCoordinates.count - 1 {
                                let curr = CLLocation(
                                    latitude: tmapCoordinates[i].latitude,
                                    longitude: tmapCoordinates[i].longitude
                                )
                                let next = CLLocation(
                                    latitude: tmapCoordinates[i + 1].latitude,
                                    longitude: tmapCoordinates[i + 1].longitude
                                )
                                accumulatedDistance += curr.distance(from: next)
                            }
                            continue
                        }
                    }
                    
                    print("🔍 [회전 감지] 인덱스 \(i), 거리 \(Int(distToPoint))m, 누적거리 \(Int(accumulatedDistance))m, 방향: \(turn.korean)")
                    
                    let text = "잠시 후 \(turn.korean)입니다"
                    announceTurnText(text)
                    markConsecutiveTurns(from: i, direction: turn)
                    
                    announcedTurnIndices.insert(i)
                    lastAnnouncementTime = Date()
                    
                    lastAnnouncedDirection = turn
                    lastAnnouncedLocation = location.coordinate
                    
                    return
                }
            }
            
            if i < tmapCoordinates.count - 1 {
                let curr = CLLocation(
                    latitude: tmapCoordinates[i].latitude,
                    longitude: tmapCoordinates[i].longitude
                )
                let next = CLLocation(
                    latitude: tmapCoordinates[i + 1].latitude,
                    longitude: tmapCoordinates[i + 1].longitude
                )
                accumulatedDistance += curr.distance(from: next)
            }
        }
    }
    
    // 연속된 같은 방향 회전을 모두 기록
    private func markConsecutiveTurns(from startIndex: Int, direction: TurnDirection) {
        let searchStart = max(1, startIndex - 2)
        let searchEnd = min(tmapCoordinates.count - 2, startIndex + 2)
        
        for i in searchStart...searchEnd {
            if i == startIndex {
                continue
            }
            
            if let turn = detectTurn(at: i), turn == direction {
                announcedTurnIndices.insert(i)
                print("  └─ 연속 회전 노드 \(i)도 기록")
            }
        }
    }
    
    // 회전 감지 로직
    private func detectTurn(at index: Int) -> TurnDirection? {
        guard index > 0 && index < tmapCoordinates.count - 1 else { return nil }
        
        let vectorLength: CLLocationDistance = 10 // 최소 10m 거리 확보
        
        var beforeIndex = index
        var beforeDist: CLLocationDistance = 0
        for i in stride(from: index - 1, through: max(0, index - 10), by: -1) {
            guard i >= 0 && i + 1 < tmapCoordinates.count else { break }
            let p1 = CLLocation(latitude: tmapCoordinates[i].latitude, longitude: tmapCoordinates[i].longitude)
            let p2 = CLLocation(latitude: tmapCoordinates[i+1].latitude, longitude: tmapCoordinates[i+1].longitude)
            beforeDist += p1.distance(from: p2)
            if beforeDist >= vectorLength {
                beforeIndex = i
                break
            }
        }
        
        var afterIndex = index
        var afterDist: CLLocationDistance = 0
        for i in index..<min(index + 10, tmapCoordinates.count - 1) {
            guard i >= 0 && i + 1 < tmapCoordinates.count else { break }
            let p1 = CLLocation(latitude: tmapCoordinates[i].latitude, longitude: tmapCoordinates[i].longitude)
            let p2 = CLLocation(latitude: tmapCoordinates[i+1].latitude, longitude: tmapCoordinates[i+1].longitude)
            afterDist += p1.distance(from: p2)
            if afterDist >= vectorLength {
                afterIndex = i + 1
                break
            }
        }
        
        guard beforeIndex >= 0 && afterIndex < tmapCoordinates.count else { return nil }
        
        let p1 = tmapCoordinates[beforeIndex]
        let pCenter = tmapCoordinates[index]
        let p3 = tmapCoordinates[afterIndex]
        
        let bearing1 = bearing(from: p1, to: pCenter)
        let bearing2 = bearing(from: pCenter, to: p3)
        
        var angleDiff = bearing2 - bearing1
        if angleDiff > 180 { angleDiff -= 360 }
        if angleDiff < -180 { angleDiff += 360 }
        
        if abs(angleDiff) > turnAngleThreshold {
            return angleDiff > 0 ? .right : .left
        }
        
        return nil
    }
    
    // MARK: - 안내 실행
    private func announceTurnText(_ text: String) {
        // 이미 말하고 있으면 끊고 새로 말함 (긴급성)
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = 0.5
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
        print("🔊 음성 안내: \(text)")
    }
    
    // MARK: - 시작 안내
    private func announceStart() {
        navigationStartTime = Date()
        AudioServicesPlayAlertSound(1110)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if self.speechSynthesizer.isSpeaking {
                return
            }
            
            let text = "도보 길 안내를 시작합니다"
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            utterance.rate = 0.5
            utterance.volume = 1.0
            
            self.speechSynthesizer.speak(utterance)
            print("🔊 시작 안내: \(text)")
        }
    }
    
    // MARK: - 거리 계산
    private func calculateRemainDistance(
        fromSegmentIndex index: Int,
        progress: Double,
        projectedPoint: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        guard !tmapCoordinates.isEmpty else { return 0 }
        guard index < tmapCoordinates.count - 1 else { return 0 }
        
        let endOfSegment = CLLocation(latitude: tmapCoordinates[index+1].latitude, longitude: tmapCoordinates[index+1].longitude)
        let currentLoc = CLLocation(latitude: projectedPoint.latitude, longitude: projectedPoint.longitude)
        var remainingDistance = currentLoc.distance(from: endOfSegment)
        
        for i in (index + 1)..<(tmapCoordinates.count - 1) {
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
        if lastArrowBearing == 0 {
            arrowBearing = newBearing
            lastArrowBearing = newBearing
            return
        }
        
        var diff = newBearing - lastArrowBearing
        if diff > 180 { diff -= 360 }
        else if diff < -180 { diff += 360 }
        
        if abs(diff) < arrowBearingThreshold {
            return
        }
        
        arrowBearing = newBearing
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

// MARK: - TurnDirection
enum TurnDirection: Equatable {
    case left, right
    
    var korean: String {
        switch self {
        case .left: return "좌회전"
        case .right: return "우회전"
        }
    }
}

// 거리 계산용 Extension
extension CLLocationCoordinate2D {
    func distance(from other: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }
}
