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
    @Published var offRouteThreshold: CLLocationDistance = 25
    @Published var reachedSegmentEnd: Bool = false              // 경로 잔여거리 < 6m
    @Published var reachedFinalDestination: Bool = false        // 목적지 직선거리 < 6m

    private let segmentArrivalDistance: CLLocationDistance = 6            // 경로 단계 도착
    private let finalArrivalStraightDistance: CLLocationDistance = 6      // 최종 도착(직선거리)
    private let journeyManager: JourneyManager
    private let recalcCooldown: TimeInterval = 45
    private let accuracyGate: CLLocationAccuracy = 30
    private let warmupSeconds: TimeInterval = 5
    private let offRouteDebounce: TimeInterval = 2  // 경로 2회 이상 이탈 시만 알럿
    
    private var hasCalculatedRoute = false
    private var currentSegmentIndex: Int = 0
    private var cumulativeMeters: [Double] = [] // coords[i]까지 누적 길이
    private var totalMeters: Double { cumulativeMeters.last ?? 0 }
    private var lastRecalcAt: Date = .distantPast
    private var appStartedAt: Date = Date()
    private var offRouteSince: Date? = nil

    let loc = CLLocationManager()
    var pendingDestination: CLLocationCoordinate2D?
    var tmapCoordinates: [CLLocationCoordinate2D] = []

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

    /// 알림 닫은 직후 곧바로 다시 뜨지 않도록, 다음 재알림 허용 시점을 `seconds` 뒤로 미룸
    func deferRealert(seconds: TimeInterval = 45) {
        lastRecalcAt = Date().addingTimeInterval(seconds - recalcCooldown)
    }

    /// 뷰에서 직접 호출할 수 있는 재탐색 트리거
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
        calculateRoute(origin: origin, dest: dest)
    }

    // MARK: - Private
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
        isRerouting = false
        showRerouteAlert = false
        reachedSegmentEnd = false
        reachedFinalDestination = false
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
                await MainActor.run { self.applyTmapRoute(tmapResponse); self.finishReroute() }
            } catch {
                print("[ERROR] TMAP 에러: \(error.localizedDescription)")
                await MainActor.run { self.fallbackToAppleMaps(origin: origin, dest: dest); self.finishReroute() }
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
            ProgressLiveActivityManager.shared.updateWalkingActivity(stage: stage, newLeftDistance: totalMeters)
        }
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
                ProgressLiveActivityManager.shared.updateWalkingActivity(stage: stage, newLeftDistance: self.totalMeters)
            }
            self.finishReroute()
        }
    }

    private func finishReroute() {
        isRerouting = false
        // 알럿은 사용자가 닫을 수 있으므로 여기서 강제 off 하지 않음
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
            cumulativeMeters.append((cumulativeMeters.last ?? 0) + segment)
        }
    }

    // MARK: - 투영/스냅
    private struct Projection {
        let segmentIndex: Int  // [i, i+1]
        let t: Double          // 0...1
        let projected: CLLocationCoordinate2D
        let distance: CLLocationDistance
    }

    private func project(_ p: CLLocationCoordinate2D,
                         onto a: CLLocationCoordinate2D,
                         _ b: CLLocationCoordinate2D) -> (t: Double, proj: CLLocationCoordinate2D) {
        func metersXY(_ c: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            let R = 6378137.0
            let x = (c.longitude - p.longitude) * .pi/180 * R * cos(p.latitude * .pi/180)
            let y = (c.latitude  - p.latitude)  * .pi/180 * R
            return (x, y)
        }
        let pa = metersXY(a), pb = metersXY(b)
        let vx = pb.x - pa.x, vy = pb.y - pa.y
        let wx = -pa.x,      wy = -pa.y
        let denom = vx*vx + vy*vy
        let tVal = denom > 0 ? max(0, min(1, (wx*vx + wy*vy)/denom)) : 0
        let px = pa.x + tVal*vx, py = pa.y + tVal*vy

        let R = 6378137.0
        let dLon = px / (R * cos(p.latitude * .pi/180))
        let dLat = py / R
        let proj = CLLocationCoordinate2D(
            latitude: p.latitude + dLat * 180 / .pi,
            longitude: p.longitude + dLon * 180 / .pi
        )
        return (tVal, proj)
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
            let candidate = Projection(segmentIndex: i, t: tVal, projected: proj, distance: d)
            if let cur = best {
                if d < cur.distance { best = candidate }
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

    // 핵심 업데이트 (스냅/잔여/도착/오프루트)
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

        // 4) 도착 판정 단순화
        // 4-1) 경로 단계 도착: 남은 "경로거리"가 6m 미만
        reachedSegmentEnd = (remain < segmentArrivalDistance)

        // 4-2) 마지막 단계의 실제 도착: 목적지와의 "직선거리"가 6m 미만
        var isFinalNode = false
        if let journey = journey, let idx = journeyIndex {
            isFinalNode = (idx == journey.nodes.count - 1)
        }
        if isFinalNode, let dest = pendingDestination {
            let straight = location.distance(from: CLLocation(latitude: dest.latitude, longitude: dest.longitude))
            reachedFinalDestination = (straight < finalArrivalStraightDistance)
        } else {
            reachedFinalDestination = false
        }

        // 4-3) 기존 arrived는 호환용으로 유지:
        //      - 마지막 노드면 실제 도착(reachedFinalDestination)
        //      - 그 외에는 경로 단계 도착(reachedSegmentEnd)
        arrived = isFinalNode ? reachedFinalDestination : reachedSegmentEnd

        // 5) 화살표 (현재 heading 기준 상대 방위)
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
            ProgressLiveActivityManager.shared.updateWalkingActivity(stage: stage, newLeftDistance: remain)
        }

        // 7) 오프루트 감지 (워밍업 + 디바운스 + 쿨다운)
        let now = Date()

        // (a) 워밍업: 시작 5초 동안은 오프루트 판정 안 함
        guard now.timeIntervalSince(appStartedAt) > warmupSeconds else {
            offRouteSince = nil
            return
        }

        // (b) 이탈 여부(투영점 기준)
        let isOffRoute = (p.distance > offRouteThreshold)

        if isOffRoute {
            // 디바운스 시작 시점 기록 (없으면 now로 설정)
            if offRouteSince == nil {
                offRouteSince = now
            }

            // 디바운스가 존재하는 경우에만 처리
            if let offRouteStart = offRouteSince {
                let offRouteDuration = now.timeIntervalSince(offRouteStart)

                // 디바운스 + 쿨다운 둘 다 통과해야 알럿
                let passedDebounce = offRouteDuration > offRouteDebounce
                let passedCooldown = now.timeIntervalSince(lastRecalcAt) > recalcCooldown

                if passedDebounce && passedCooldown {
                    showRerouteAlert = true
                    lastRecalcAt = now
                    offRouteSince = nil    // 다음 알럿을 위해 초기화
                }
            }
        } else {
            // 정상 경로 복귀 → 디바운스 초기화
            offRouteSince = nil
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
