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
    @Published var offRouteThreshold: CLLocationDistance = 20
    @Published var reachedSegmentEnd: Bool = false              // 경로 잔여거리 < 6m
    @Published var reachedFinalDestination: Bool = false        // 목적지 직선거리 < 6m or 12m
    @Published var manuallyArrived: Bool = false

    private let segmentArrivalDistance: CLLocationDistance = 12            // 경로 단계 도착
    private let journeyManager: JourneyManager
    private let recalcCooldown: TimeInterval = 45
    private let accuracyGate: CLLocationAccuracy = 50
    private let warmupSeconds: TimeInterval = 5
    private let offRouteDebounce: TimeInterval = 2  // 경로 2회 이상 이탈 시만 알럿
    
    private var finalArrivalStraightDistance: CLLocationDistance = 12      // 최종 도착(직선거리)
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
            if index == journey.nodes.count - 1 {   // 최종도착 도보일 경우에만 6m 반경
                finalArrivalStraightDistance = 6
            }
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

    /// 알림 닫은 직후 곧바로 다시 뜨지 않도록, 다음 재알림 허용 시점을 seconds 뒤로 미룸
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
        manuallyArrived = false
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
        ProgressLiveActivityManager.totalDistance = totalMeters
        ProgressLiveActivityManager.maxProgressValue = 0
        ProgressLiveActivityManager.shared.updateWalkingActivity(newLeftDistance: totalMeters)
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

            ProgressLiveActivityManager.shared.updateWalkingActivity( newLeftDistance: self.totalMeters)
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

        guard !manuallyArrived else { return }

        guard !tmapCoordinates.isEmpty else {
            bigDistanceText = "-- m"
            return
        }

        // GPS 정확도 체크
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy < accuracyGate else { return }

        // 1) 투영
        guard let p = nearestProjection(
            to: location.coordinate,
            on: tmapCoordinates
        ) else { return }

        // 2) 세그먼트 점프(진행)
        currentSegmentIndex = max(
            currentSegmentIndex,
            p.segmentIndex + (p.t >= 0.9 ? 1 : 0)
        )

        // 3) 잔여거리 계산
        let base = cumulativeMeters.indices.contains(p.segmentIndex)
            ? cumulativeMeters[p.segmentIndex]
            : 0

        let nextIndex = p.segmentIndex + 1
        let segLen = (cumulativeMeters.indices.contains(nextIndex)
                      ? cumulativeMeters[nextIndex] - base
                      : 0)

        let progressed = base + segLen * p.t
        let remain = max(0, totalMeters - progressed)
        bigDistanceText = "\(Int(remain)) m"

        // 4) 도착 판정 ------------------------------

//        // 4-1) 경로(세그먼트) 단위의 도착
//        let segmentRemain = segLen * (1 - p.t)
//        reachedSegmentEnd = (segmentRemain < segmentArrivalDistance)
//        if reachedSegmentEnd {
//            // 세그먼트는 0...(count-2)까지만 유효
//            let cap = max(0, tmapCoordinates.count - 2)
//            // 뒤로 가지 않도록 하면서, 이번 프레임의 투영 세그먼트+1까지는 최소 전진
//            currentSegmentIndex = min(max(currentSegmentIndex, p.segmentIndex + 1), cap)
//        }
        // 세그먼트 끝 점 좌표
        if tmapCoordinates.indices.contains(p.segmentIndex + 1) {
            let segmentEnd = tmapCoordinates[p.segmentIndex + 1]
            let distanceToSegmentEnd = location.distance(
                from: CLLocation(latitude: segmentEnd.latitude, longitude: segmentEnd.longitude)
            )
            
            reachedSegmentEnd = (distanceToSegmentEnd < segmentArrivalDistance)
            
            if reachedSegmentEnd {
                // 세그먼트는 0...(count-2)까지만 유효
                let cap = max(0, tmapCoordinates.count - 2)
                // 뒤로 가지 않도록 하면서 최소 전진
                currentSegmentIndex = min(max(currentSegmentIndex, p.segmentIndex + 1), cap)
            }
        } else {
            reachedSegmentEnd = false
        }

        // 4-2) 마지막 세그먼트 여부
        let isLastRouteSegment = (p.segmentIndex == tmapCoordinates.count - 2)

        if let dest = pendingDestination {
            let straight = location.distance(
                from: CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            )
            reachedFinalDestination = isLastRouteSegment && (straight < finalArrivalStraightDistance)
        }

        // 4-3) arrived
        if !manuallyArrived {
            arrived = reachedFinalDestination || (remain < finalArrivalStraightDistance)
        }
        
        // 4-4) arrived 확정 시 manual lock
        if arrived && !manuallyArrived {
            manuallyArrived = true
        }

        // 5) 화살표
        if let hdg = heading?.trueHeading, hdg >= 0 {
            let nextIdx = min(tmapCoordinates.count - 1, p.segmentIndex + 1)
            let target = tmapCoordinates.indices.contains(nextIdx)
                ? tmapCoordinates[nextIdx]
                : lastOrSelfCoordinate(default: location.coordinate)
            
            var bearingAbs = bearing(from: location.coordinate, to: target)
            if (p.t > 0.1 && p.t < 0.9 && p.distance < 7) || segLen < 12 {
                bearingAbs = bearing(from: p.projected, to: target)
            }
            arrowBearing = fmod((bearingAbs - hdg + 360), 360)
        }

        // 6) 라이브 액티비티
        if !arrived {
            ProgressLiveActivityManager.shared.updateWalkingActivity(newLeftDistance: remain)
        }
        
        // 7) 오프루트 감지 (워밍업 + 디바운스 + 쿨다운)
        let now = Date()

        // (a) 워밍업: 앱 시작 후 5초는 감지하지 않음
        guard now.timeIntervalSince(appStartedAt) > warmupSeconds else {
            offRouteSince = nil
            return
        }

        // (b) 엔드포인트 거리 계산 추가 --------------------
        let pointDistance = minEndpointDistance(
            around: p.segmentIndex,
            location: location
        )

        // (c) 정확도 기반 동적 threshold 계산 ----------------
        let acc = max(0, location.horizontalAccuracy)

        // 투영 threshold
        var projEff = offRouteThreshold + min(40.0, acc * 0.5)

        // 엔드포인트 threshold
        var pointEff = offRouteThreshold + 15 + min(40.0, acc * 0.3)

        // (d) 목적지 근방일 경우 threshold 완화 ----------------
        if isLastRouteSegment {
            projEff += 20
            pointEff += 20
        }

        // 오프루트 판정 (최종 적용)
        let isOffRoute = (p.distance > projEff) && (pointDistance > pointEff)

        // MARK: 오프루트 디바운스 처리
        if isOffRoute {
            if offRouteSince == nil {
                offRouteSince = now       // 최초 이탈 시각 기록
            }

            if let start = offRouteSince {
                let elapsed = now.timeIntervalSince(start)
                let passedDebounce = elapsed > offRouteDebounce
                let passedCooldown = now.timeIntervalSince(lastRecalcAt) > recalcCooldown

                if passedDebounce && passedCooldown {
                    showRerouteAlert = true
                    lastRecalcAt = now
                    offRouteSince = nil    // 재호출 방지
                }
            }
        } else {
            // 정상 복귀 → 이탈 상태 초기화
            offRouteSince = nil
        }
    }

    private func lastOrSelfCoordinate(default coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if let last = tmapCoordinates.last { return last }
        return coord
    }
    
    // 현재 세그먼트(i, i+1)의 엔드포인트들 기준 최소 직선거리 계산
    private func minEndpointDistance(around segmentIndex: Int,
                                     location: CLLocation) -> CLLocationDistance {
        var best = CLLocationDistance.greatestFiniteMagnitude
        // i
        if tmapCoordinates.indices.contains(segmentIndex) {
            let a = tmapCoordinates[segmentIndex]
            let dA = location.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude))
            best = min(best, dA)
        }
        // i+1
        let next = segmentIndex + 1
        if tmapCoordinates.indices.contains(next) {
            let b = tmapCoordinates[next]
            let dB = location.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            best = min(best, dB)
        }
        return best
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
