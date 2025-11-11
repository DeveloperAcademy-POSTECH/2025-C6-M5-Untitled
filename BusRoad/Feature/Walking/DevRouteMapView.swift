import SwiftUI
import MapKit
import Combine

struct DevRouteMapView: View {
    // MARK: - Inputs
    let tmapCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let destination: CLLocationCoordinate2D?
    let deviceHeading: CLLocationDirection?   // 0...360 (북=0°, 시계방향)

    // MARK: - Camera
    @State private var camera: MapCameraPosition = .automatic
    @State private var didSetInitialCamera = false

    // 1인칭 느낌
    private let firstPersonPitch: CGFloat = 45
    private let firstPersonDistance: CLLocationDistance = 240

    // MARK: - Puck (바닥 고정, 단위 m)
    private let circleRadius: CLLocationDistance = 6
    private let arrowGap: CLLocationDistance    = 2
    private let arrowLength: CLLocationDistance = 6
    private let arrowWidth: CLLocationDistance  = 6

    // MARK: - Colors
    private let routeColor: Color  = .blue
    private let strokeColor: Color = .primarywhite

    // MARK: - 부드러운 회전(현위치 화살표 전용)
    @State private var smoothHeading: Double = 0
    @State private var targetHeading: Double = 0
    private let fps: Double = 60
    private let baseAlpha: Double = 0.32
    private let maxAlpha:  Double = 0.85

    var body: some View {
        Map(position: $camera) {
            // 1) 경로
            if !tmapCoordinates.isEmpty {
                MapPolyline(coordinates: tmapCoordinates)
                    .stroke(routeColor, lineWidth: 5)
            }
            
            // 1-1) 경로의 모든 좌표에 작은 점 표시 (디버깅용!!)
            ForEach(Array(tmapCoordinates.enumerated()), id: \.offset) { idx, coord in
                MapCircle(center: coord, radius: 1.5)   // 반지름 1.5m 정도의 작은 점
                    .foregroundStyle(.red.opacity(0.8))
            }

            // 2) 목적지 (경로 없을 때)
            if let dest = destination, tmapCoordinates.isEmpty {
                Marker("목적지", coordinate: dest)
            }

            // 3) 바닥 고정 현위치 마커 (원 + 삼각형)
            if let loc = userLocation {
                let puck = puckGeometry(center: loc.coordinate,
                                        heading: smoothHeading,
                                        r: circleRadius,
                                        gap: arrowGap,
                                        len: arrowLength,
                                        w: arrowWidth)

                MapCircle(center: puck.center, radius: circleRadius)
                    .foregroundStyle(routeColor)
                    .stroke(strokeColor, lineWidth: 2)

                MapPolygon(coordinates: puck.triangle)
                    .foregroundStyle(routeColor)
                    .stroke(strokeColor, lineWidth: 1)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .onAppear {
            if didSetInitialCamera == false {
                setInitialCamera()
                didSetInitialCamera = true
            }
            // 화살표 스무딩 초기화
            let initHead = normalizeDeg(deviceHeading ?? 0)
            targetHeading = initHead
            smoothHeading = initHead
        }
        // 이후에는 카메라(방향/피치) 손대지 않음 — 아래는 화살표(글리프)만 부드럽게 회전
        .onChange(of: deviceHeading) { _, newValue in
            let new = normalizeDeg(newValue ?? targetHeading)
            targetHeading = new
        }
        .onReceive(Timer.publish(every: 1.0 / fps, on: .main, in: .common).autoconnect()) { _ in
            let delta = shortestDelta(from: smoothHeading, to: targetHeading)
            if abs(delta) < 0.05 {
                smoothHeading = targetHeading
            } else {
                let alpha = adaptiveAlpha(for: delta)
                smoothHeading = normalizeDeg(smoothHeading + delta * alpha)
            }
        }
    }

    // MARK: - Camera helpers (초기 1회만 호출)

    /// 맵을 열 때 "현재 위치 → 지금 향해야 하는 다음 좌표" 방향으로 1인칭 시야 설정
    private func setInitialCamera() {
        // 유저 위치 + 경로 2점 이상: 유저 → 다음 좌표 방향
        if let user = userLocation?.coordinate, tmapCoordinates.count >= 2 {
            let next = currentNextCoordinate(from: user, on: tmapCoordinates)
            let hdg  = bearing(from: user, to: next)
            camera = .camera(
                MapCamera(centerCoordinate: user,
                          distance: firstPersonDistance,
                          heading: hdg,
                          pitch: firstPersonPitch)
            )
            return
        }

        // 경로만 있으면 전체 프레이밍
        if !tmapCoordinates.isEmpty {
            let poly = MKPolyline(coordinates: tmapCoordinates, count: tmapCoordinates.count)
            let rect = poly.boundingMapRect
            let region = MKCoordinateRegion(rect)
            let center = region.center
            let distance = estimatedDistance(for: rect)
            camera = .camera(
                MapCamera(centerCoordinate: center,
                          distance: distance,
                          heading: 0,
                          pitch: 55)
            )
            return
        }

        // 목적지만 있을 때
        if let dest = destination {
            camera = .camera(
                MapCamera(centerCoordinate: dest,
                          distance: 900,
                          heading: 0,
                          pitch: 55)
            )
        }
    }

    private func estimatedDistance(for rect: MKMapRect) -> CLLocationDistance {
        let midPoint = MKMapPoint(x: rect.midX, y: rect.midY)
        let midCoord = midPoint.coordinate
        let ppm = MKMapPointsPerMeterAtLatitude(midCoord.latitude)
        let widthMeters  = rect.size.width  / ppm
        let heightMeters = rect.size.height / ppm
        let maxSide = max(widthMeters, heightMeters)
        // 패딩 & 상하한
        return max(600, min(maxSide * 1.4, 8000))
    }

    // MARK: - Heading smoothing (화살표 전용)

    private func normalizeDeg(_ x: Double) -> Double {
        var v = x.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    /// a→b 최단 회전 [-180, 180]
    private func shortestDelta(from a: Double, to b: Double) -> Double {
        let d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { return d - 360 }
        if d < -180 { return d + 360 }
        return d
    }

    /// 큰 회전은 빠르게, 작은 흔들림은 천천히
    private func adaptiveAlpha(for delta: Double) -> Double {
        let norm = min(abs(delta) / 90.0, 1.0)
        return baseAlpha + (maxAlpha - baseAlpha) * norm
    }

    // MARK: - Ground puck geometry (지도 좌표계, m)

    private func puckGeometry(center: CLLocationCoordinate2D,
                              heading: CLLocationDirection,
                              r: CLLocationDistance,
                              gap: CLLocationDistance,
                              len: CLLocationDistance,
                              w: CLLocationDistance) -> (center: CLLocationCoordinate2D,
                                                         triangle: [CLLocationCoordinate2D]) {
        // heading: 북=0°, 시계방향(+)
        let rad = heading * .pi / 180
        // forward (east/north)
        let fx = sin(rad)
        let fy = cos(rad)
        // left perpendicular
        let lx = -fy
        let ly =  fx

        func offset(from origin: CLLocationCoordinate2D, east: Double, north: Double) -> CLLocationCoordinate2D {
            let R = 6_378_137.0
            let dLat = north / R * 180.0 / .pi
            let dLon = east  / (R * cos(origin.latitude * .pi / 180.0)) * 180.0 / .pi
            return .init(latitude: origin.latitude + dLat, longitude: origin.longitude + dLon)
        }

        // 삼각형 점들
        let baseCenter = offset(from: center, east: (r + gap) * fx, north: (r + gap) * fy)
        let tip        = offset(from: center, east: (r + gap + len) * fx, north: (r + gap + len) * fy)
        let leftBase   = offset(from: baseCenter, east: (w / 2) * lx, north: (w / 2) * ly)
        let rightBase  = offset(from: baseCenter, east: -(w / 2) * lx, north: -(w / 2) * ly)

        return (center, [tip, leftBase, rightBase])
    }

    // MARK: - 경로 유틸(투영 & 다음 점 선택)

    private struct Projection {
        let segmentIndex: Int  // [i, i+1]
        let t: Double          // 0...1
        let distanceMeters: Double
    }

    private func nearestProjection(to p: CLLocationCoordinate2D,
                                   on coords: [CLLocationCoordinate2D]) -> Projection {
        if coords.count < 2 {
            return Projection(segmentIndex: 0, t: 0, distanceMeters: .greatestFiniteMagnitude)
        }

        func toMeters(_ c: CLLocationCoordinate2D, origin: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            let R = 6378137.0
            let x = (c.longitude - origin.longitude) * .pi/180 * R * cos(origin.latitude * .pi/180)
            let y = (c.latitude  - origin.latitude)  * .pi/180 * R
            return (x, y)
        }

        var best = Projection(segmentIndex: 0, t: 0, distanceMeters: .greatestFiniteMagnitude)
        var i = 0
        while i < coords.count - 1 {
            let a = coords[i], b = coords[i+1]
            let A = toMeters(a, origin: p)
            let B = toMeters(b, origin: p)
            let vx = B.x - A.x, vy = B.y - A.y
            let wx = -A.x,      wy = -A.y
            let denom = vx*vx + vy*vy
            let t = denom > 0 ? max(0, min(1, (wx*vx + wy*vy) / denom)) : 0
            let px = A.x + t*vx, py = A.y + t*vy
            let d  = (px*px + py*py).squareRoot()
            if d < best.distanceMeters {
                best = Projection(segmentIndex: i, t: t, distanceMeters: d)
            }
            i += 1
        }
        return best
    }

    /// 현재 진행 세그먼트의 "바라볼 다음 좌표" 선택
    private func currentNextCoordinate(from user: CLLocationCoordinate2D,
                                       on coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        if coords.count == 1 { return coords[0] }
        if coords.count < 2 { return user }

        let proj = nearestProjection(to: user, on: coords)
        var idx = min(proj.segmentIndex + 1, coords.count - 1)
        // 투영이 거의 끝에 가까우면 다음 세그먼트로 한 칸 더
        if proj.t > 0.9, idx + 1 < coords.count { idx += 1 }
        return coords[idx]
    }

    /// 북=0°, 시계방향(+)
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let φ1 = from.latitude * .pi / 180
        let φ2 = to.latitude   * .pi / 180
        let dλ = (to.longitude - from.longitude) * .pi / 180
        let y  = sin(dλ) * cos(φ2)
        let x  = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        let θ  = atan2(y, x) * 180 / .pi
        var deg = θ.truncatingRemainder(dividingBy: 360)
        if deg < 0 { deg += 360 }
        return deg
    }
}
