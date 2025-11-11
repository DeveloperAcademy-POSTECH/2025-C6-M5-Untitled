import Foundation
import Combine
import CoreLocation
import MapKit

final class WalkingViewModel: NSObject, ObservableObject {
    
    // MARK: - Published UI State
    @Published var bigDistanceText: String = "-- m"
    @Published var arrowBearing: CLLocationDirection = 0
    @Published var nextCards: [String] = []
    @Published var arrived: Bool = false
    @Published var journey: Journey?
    @Published var journeyIndex: Int?
    
    @Published var showAlert: Bool = false
    @Published var showRerouteAlert: Bool = false
    
    @Published var showDevSheet: Bool = false
    @Published var tmapTotalDistance: Int = 0
    @Published var showVerifyingStop: Bool = false
    @Published var isRerouting: Bool = false
    @Published var offRouteThreshold: CLLocationDistance = 50 // 기본 50m
    
    // MARK: - Internal State
    private var hasCalculatedRoute = false
    private var stepSwitchDistance: CLLocationDistance = 6
    private var journeyManager: JourneyManager
    
    // 경로 진행/거리
    private var currentSegmentIndex: Int = 0
    private var cumulativeMeters: [Double] = [] // coords[i]까지 누적 길이
    private var totalMeters: Double { cumulativeMeters.last ?? 0 }
    
    // 오프루트/쿨다운
    var offRouteViolations = 0
    private var lastRecalcAt: Date = .distantPast
    private var recalcCooldown: TimeInterval = 45
    private var accuracyGate: CLLocationAccuracy = 50
    
    // 위치/경로
    let loc = CLLocationManager()
    var pendingDestination: CLLocationCoordinate2D?
    var tmapCoordinates: [CLLocationCoordinate2D] = []
    
    // MARK: - Anti False-OffRoute (새 로직 관련 상태)
    private let nearDestBufferRadius: CLLocationDistance = 25       // 목적지 근방에서는 오프루트 비활성화
    private let arrivalRadius: CLLocationDistance = 18               // 도착 판정 반경
    private let shortSegMeters: CLLocationDistance = 12              // "짧은 세그먼트" 기준
    private let emaAlpha: Double = 0.4                               // projection distance EMA
    private var emaProjectionDistance: Double? = nil
    
    // 추세 판단용 버퍼 (최근 n회)
    private var recentProjDistances: [Double] = []
    private let trendWindow: Int = 4
    
    // MARK: - Init
    init(journeyManager: JourneyManager = .shared) {
        self.journeyManager = journeyManager
        super.init()
        loc.delegate = self
        loc.allowsBackgroundLocationUpdates = true
        loc.pausesLocationUpdatesAutomatically = false
        loc.showsBackgroundLocationIndicator = true
        loc.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        loc.headingFilter = 1
        loc.headingOrientation = .portrait
        
        if let journey = journeyManager.selectedJourney,
           let index = journeyManager.journeyIndex {
            self.journey = journey
            self.journeyIndex = index
        }
    }
    
    // MARK: - Public
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
        let c = CLLocationCoordinate2D(latitude: node.end.latitude, longitude: node.end.longitude)
        setDestination(c)
    }
    
    func setOffRouteThreshold(_ meters: Int) {
        offRouteThreshold = CLLocationDistance(meters)
    }
    
    func deferRealert(seconds: TimeInterval = 45) {
        // 알림 닫은 직후 바로 다시 뜨지 않도록 살짝 보정
        lastRecalcAt = Date().addingTimeInterval(seconds - recalcCooldown)
    }
    
    func rerouteIfNeeded() {
        guard let origin = loc.location?.coordinate,
              let dest = pendingDestination else {
            if let journey = journey, let idx = journeyIndex {
                switch journey.nodes[idx] {
                case .walk(let node): setDestination(from: node)
                default: break
                }
            }
            return
        }
        isRerouting = true
        recalcCooldown = min(recalcCooldown * 1.5, 180) // 최대 3분
        calculateRoute(origin: origin, dest: dest)
    }
    
    // MARK: - Private: Route lifecycle
    private func resetRouteState() {
        tmapCoordinates = []
        tmapTotalDistance = 0
        hasCalculatedRoute = false
        arrived = false
        bigDistanceText = "-- m"
        arrowBearing = 0
        nextCards = []
        currentSegmentIndex = 0
        cumulativeMeters = []
        offRouteViolations = 0
        isRerouting = false
        showRerouteAlert = false
        
        // Anti False-OffRoute 상태 초기화
        emaProjectionDistance = nil
        recentProjDistances.removeAll()
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
                print("[DEBUG] TMAP 경로 계산 시작")
                let tmapResponse = try await tmapService.getPedestrianRoute(from: origin, to: dest)
                await MainActor.run { self.applyTmapRoute(tmapResponse) }
            } catch {
                print("[ERROR] TMAP 에러: \(error.localizedDescription)")
                await MainActor.run { self.fallbackToAppleMaps(origin: origin, dest: dest) }
            }
        }
    }
    
    // MARK: - TMAP 경로 적용
    private func applyTmapRoute(_ tmapResponse: TmapPedestrianResponse) {
        // 1) 좌표 수집
        var allCoordinates: [CLLocationCoordinate2D] = []
        for feature in tmapResponse.features {
            for coord in feature.geometry.coordinates where coord.count >= 2 {
                allCoordinates.append(.init(latitude: coord[1], longitude: coord[0]))
            }
        }
        tmapCoordinates = allCoordinates
        print("TMAP 좌표 \(allCoordinates.count)개 수집 완료")
        
        // 2) 누적거리 프리컴퓨트
        buildCumulative()
        
        // 3) 총거리/표시
        tmapTotalDistance = Int(totalMeters)
        bigDistanceText = "\(Int(totalMeters)) m"
        
        // 4) 안내 카드 (최대 3개)
        var cards: [String] = []
        for feature in tmapResponse.features {
            if let description = feature.properties.description,
               let distance = feature.properties.distance {
                cards.append("\(description) \(distance)m")
            }
        }
        nextCards = Array(cards.prefix(3))
        print("안내 카드: \(nextCards)")
        
        // 5) 라이브액티비티
        if let journey = journey, let journeyIndex = journeyIndex {
            let isLastNode = (journey.nodes.count - 1 == journeyIndex + 1)
            let stage = isLastNode ? RouteStage.walkingToDestination.rawValue : RouteStage.walkingToBus.rawValue
            ProgressLiveActivityManager.totalDistance = totalMeters
            ProgressLiveActivityManager.maxProgressValue = 0
            ProgressLiveActivityManager.shared.updateWalkingActivity(newLeftDistance: totalMeters)
        }
        
        // 재탐색 종료
        finishReroute()
    }
    
    // MARK: - Apple Maps Fallback
    private func fallbackToAppleMaps(origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) {
        print("Apple Maps로 fallback")
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        req.transportType = .walking
        
        MKDirections(request: req).calculate { [weak self] resp, err in
            guard let self = self else { return }
            if let err = err {
                self.bigDistanceText = "경로 계산 실패"
                print("Apple Maps 에러: \(err.localizedDescription)")
                self.finishReroute()
                return
            }
            guard let routes = resp?.routes, !routes.isEmpty,
                  let shortest = routes.min(by: { $0.distance < $1.distance }) else {
                self.bigDistanceText = "경로 없음"
                self.finishReroute()
                return
            }
            
            // 좌표 변환
            let polyline = shortest.polyline
            let points = polyline.points()
            var coords: [CLLocationCoordinate2D] = []
            for i in 0..<polyline.pointCount {
                coords.append(points[i].coordinate)
            }
            
            self.tmapCoordinates = coords
            self.buildCumulative()
            self.tmapTotalDistance = Int(self.totalMeters)
            ProgressLiveActivityManager.totalDistance = self.totalMeters
            self.bigDistanceText = "\(Int(self.totalMeters)) m"
            
            if let journey = self.journey, let journeyIndex = self.journeyIndex {
                let isLastNode = (journey.nodes.count - 1 == journeyIndex + 1)
                let stage = isLastNode ? RouteStage.walkingToDestination.rawValue : RouteStage.walkingToBus.rawValue
                ProgressLiveActivityManager.shared.updateWalkingActivity( newLeftDistance: self.totalMeters)
            }
            self.finishReroute()
        }
    }
    
    private func finishReroute() {
        isRerouting = false
        offRouteViolations = 0
        emaProjectionDistance = nil
        recentProjDistances.removeAll()
    }
    
    // MARK: - 누적거리
    private func buildCumulative() {
        cumulativeMeters = []
        guard !tmapCoordinates.isEmpty else { return }
        cumulativeMeters.reserveCapacity(tmapCoordinates.count)
        cumulativeMeters.append(0)
        
        for i in 1..<tmapCoordinates.count {
            let from = CLLocation(latitude: tmapCoordinates[i-1].latitude,
                                  longitude: tmapCoordinates[i-1].longitude)
            let to   = CLLocation(latitude: tmapCoordinates[i].latitude,
                                  longitude: tmapCoordinates[i].longitude)
            let segment = from.distance(from: to)
            if let last = cumulativeMeters.last {
                cumulativeMeters.append(last + segment)
            } else {
                cumulativeMeters.append(segment)
            }
        }
    }
    
    // MARK: - 투영/스냅
    private struct Projection {
        let segmentIndex: Int      // [i, i+1]
        let t: Double              // 0...1
        let projected: CLLocationCoordinate2D
        let distance: CLLocationDistance
        let segmentLength: CLLocationDistance
    }
    
    private func metersXY(_ origin: CLLocationCoordinate2D, relativeTo p: CLLocationCoordinate2D) -> (x: Double, y: Double) {
        let R = 6378137.0
        let x = (origin.longitude - p.longitude) * .pi/180 * R * cos(p.latitude * .pi/180)
        let y = (origin.latitude  - p.latitude)  * .pi/180 * R
        return (x, y)
    }
    
    private func project(_ p: CLLocationCoordinate2D,
                         onto a: CLLocationCoordinate2D,
                         _ b: CLLocationCoordinate2D) -> (t: Double, proj: CLLocationCoordinate2D) {
        let pa = metersXY(a, relativeTo: p), pb = metersXY(b, relativeTo: p)
        let vx = pb.x - pa.x, vy = pb.y - pa.y
        let wx = -pa.x,      wy = -pa.y
        let denom = vx*vx + vy*vy
        let tVal = denom > 0 ? max(0, min(1, (wx*vx + wy*vy)/denom)) : 0
        let px = pa.x + tVal*vx, py = pa.y + tVal*vy
        
        let R = 6378137.0   // 지구 반지름
        let dLon = px / (R * cos(p.latitude * .pi/180))
        let dLat = py / R
        let proj = CLLocationCoordinate2D(
            latitude: p.latitude + dLat * 180 / .pi,
            longitude: p.longitude + dLon * 180 / .pi
        )
        return (tVal, proj)
    }
    
    private func segmentLength(at i: Int) -> CLLocationDistance {
        guard i >= 0, i+1 < tmapCoordinates.count else { return 0 }
        let a = CLLocation(latitude: tmapCoordinates[i].latitude, longitude: tmapCoordinates[i].longitude)
        let b = CLLocation(latitude: tmapCoordinates[i+1].latitude, longitude: tmapCoordinates[i+1].longitude)
        return a.distance(from: b)
    }
    
    private func nearestProjection(to user: CLLocationCoordinate2D,
                                   on coords: [CLLocationCoordinate2D]) -> Projection? {
        guard coords.count >= 2 else { return nil }
        var best: Projection? = nil
        for i in 0..<(coords.count-1) {
            let a = coords[i], b = coords[i+1]
            let (tVal, proj) = project(user, onto: a, b)
            let d = CLLocation(latitude: user.latitude, longitude: user.longitude)
                .distance(from: CLLocation(latitude: proj.latitude, longitude: proj.longitude))
            let segLen = segmentLength(at: i)
            let candidate = Projection(segmentIndex: i, t: tVal, projected: proj, distance: d, segmentLength: segLen)
            if let currentBest = best {
                if d < currentBest.distance {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }
        return best
    }
    
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let φ1 = from.latitude * .pi/180, φ2 = to.latitude * .pi/180
        let dλ = (to.longitude - from.longitude) * .pi/180
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        let θ = atan2(y, x) * 180 / .pi
        return fmod(θ + 360, 360)
    }
    
    // MARK: - Trend helpers
    private func push(_ value: Double, into array: inout [Double], window: Int) {
        array.append(value)
        if array.count > window { array.removeFirst(array.count - window) }
    }
    
    private func netIncrease(_ array: [Double]) -> Double {
        guard let first = array.first, let last = array.last else { return 0 }
        return last - first
    }
    
    private func updateWithTmapRoute(location: CLLocation, heading: CLHeading?) {
        guard !tmapCoordinates.isEmpty else {
            bigDistanceText = "-- m"
            return
        }
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy < accuracyGate else { return }
        
        // 1) 투영
        guard let p = nearestProjection(to: location.coordinate, on: tmapCoordinates) else { return }
        
        // 2) 세그먼트 점프 (진행)
        currentSegmentIndex = max(currentSegmentIndex, p.segmentIndex + (p.t >= 0.999 ? 1 : 0))
        
        // 3) 잔여거리 계산
        let base = cumulativeMeters.indices.contains(p.segmentIndex) ? cumulativeMeters[p.segmentIndex] : 0
        let nextIndex = p.segmentIndex + 1
        let segLen: Double = (cumulativeMeters.indices.contains(nextIndex) ? cumulativeMeters[nextIndex] - base : 0)
        let progressed = base + segLen * p.t
        let remain = max(0, totalMeters - progressed)
        bigDistanceText = "\(Int(remain)) m"
        
        // 4) 도착 판정
        if let last = tmapCoordinates.last {
            let destD = location.distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
            if let journey = journey,
                let index = journeyIndex,
                index == journey.nodes.count - 1 {
                if remain < max(stepSwitchDistance, 6), destD < arrivalRadius {
                    arrived = true
                }
            } else if let journey = journey,
                      let index = journeyIndex,
                      index != journey.nodes.count - 1 {
                if remain < max(stepSwitchDistance, 12), destD < arrivalRadius {
                    arrived = true
                }
            }
        }
        
        // 5) 화살표 베어링 (UI용)
        if let hdg = heading?.trueHeading, hdg >= 0 {
            let nextIdx = min(tmapCoordinates.count - 1, p.segmentIndex + 1)
            let target = tmapCoordinates.indices.contains(nextIdx) ? tmapCoordinates[nextIdx] : lastOrSelfCoordinate(default: location.coordinate)
            let bearingAbs = bearing(from: p.projected, to: target)
            arrowBearing = fmod((bearingAbs - hdg + 360), 360)
        }
        
        // 6) 라이브액티비티
        if let journey = journey, let journeyIndex = journeyIndex {
            let isLastNode = (journey.nodes.count - 1 == journeyIndex + 1)
            let stage = isLastNode ? RouteStage.walkingToDestination.rawValue : RouteStage.walkingToBus.rawValue
            ProgressLiveActivityManager.shared.updateWalkingActivity(newLeftDistance: remain)
        }
        
        // 7) Anti False-OffRoute + 실제 OffRoute 탐지
        guard let dest = tmapCoordinates.last else { return }
        let destDistance = location.distance(from: CLLocation(latitude: dest.latitude, longitude: dest.longitude))
        
        // 목적지 근방에서는 OffRoute 감지 비활성화
        if destDistance <= nearDestBufferRadius {
            offRouteViolations = 0
            emaProjectionDistance = nil
            recentProjDistances.removeAll()
            return
        }
        
        // EMA로 projection distance 안정화
        let projD = p.distance
        if let ema = emaProjectionDistance {
            emaProjectionDistance = ema * (1 - emaAlpha) + projD * emaAlpha
        } else {
            emaProjectionDistance = projD
        }
        let emaProj = emaProjectionDistance ?? projD
        
        // EMA projection distance만 기반으로 판단
        // 목적지 거리 추세(destNetInc) 및 heading 기반 신호 완전히 제거
        
        // "짧은 세그먼트"는 projection 튐 방지를 위해 projection 증가 추세만 사용
        push(emaProj, into: &recentProjDistances, window: trendWindow)
        let projNetInc = netIncrease(recentProjDistances)
        
        // 동적 threshold (accuracy 나쁠수록 threshold 증가)
        let accuracyBoost = max(0, min(30, location.horizontalAccuracy - 10))
        let dynamicThreshold = offRouteThreshold + accuracyBoost
        
        // Base condition: EMA projection > threshold
        let baseCondition = emaProj > dynamicThreshold
        
        // Short segment → projection 추세까지 증가해야 OffRoute 인정
        let isShortSeg = p.segmentLength <= shortSegMeters
        let multiSignalCondition =
        isShortSeg
        ? (baseCondition && projNetInc > 2)
        : baseCondition
        
        if multiSignalCondition {
            offRouteViolations += 1
        } else if emaProj <= dynamicThreshold * 0.7 {
            // 충분히 복귀한 것으로 판단하여 카운터 리셋
            offRouteViolations = 0
        }
        
        // 연속 위반 + 쿨다운 체크
        if offRouteViolations >= 3, Date().timeIntervalSince(lastRecalcAt) > recalcCooldown {
            showRerouteAlert = true
            lastRecalcAt = Date()
        }
    }
    
    private func lastOrSelfCoordinate(default coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if let last = tmapCoordinates.last { return last }
        return coord
    }
}

// MARK: - CLLocationManagerDelegate
extension WalkingViewModel: CLLocationManagerDelegate {
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
}
