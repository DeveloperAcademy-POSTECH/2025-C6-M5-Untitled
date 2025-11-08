import SwiftUI
import MapKit
import Combine

@available(iOS 17.0, *)
struct DevRouteMapView: View {
    // Inputs
    let tmapCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let destination: CLLocationCoordinate2D?
    let deviceHeading: CLLocationDirection?   // 0...360 (북=0°, 시계방향)

    // Camera state
    @State private var camera: MapCameraPosition = .automatic
    @State private var didSetInitialCamera = false

    // Puck (ground-attached) geometry in meters
    private let circleRadius: CLLocationDistance = 6
    private let arrowGap: CLLocationDistance    = 2
    private let arrowLength: CLLocationDistance = 6   // smaller triangle
    private let arrowWidth: CLLocationDistance  = 6

    // Colors (replace with your palette if you want)
    private let routeColor: Color  = .blue
    private let strokeColor: Color = .primarywhite

    // Smooth heading (adaptive)
    @State private var smoothHeading: Double = 0      // drawn angle
    @State private var targetHeading: Double = 0      // incoming device angle (normalized)

    private let fps: Double     = 60
    private let baseAlpha: Double = 0.32   // minimum follow speed
    private let maxAlpha:  Double = 0.85   // speed for large turns

    var body: some View {
        Map(position: $camera) {
            // 1) Route polyline
            if !tmapCoordinates.isEmpty {
                MapPolyline(coordinates: tmapCoordinates)
                    .stroke(routeColor, lineWidth: 5)
            }

            // 2) Destination marker (simple) when no route
            if let dest = destination, tmapCoordinates.isEmpty {
                Marker("목적지", coordinate: dest)
            }

            // 3) Ground-attached current location puck (circle + triangle)
            if let loc = userLocation {
                let puck = puckGeometry(center: loc.coordinate,
                                        heading: smoothHeading, // smoothed
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
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .task {
            // Initial camera
            if didSetInitialCamera == false {
                setInitialCamera()
                didSetInitialCamera = true
            }
            // Initialize heading
            let initHead = normalizeDeg(deviceHeading ?? 0)
            targetHeading = initHead
            smoothHeading = initHead
        }
        // Reframe on route change (CLLocationCoordinate2D != Equatable → watch count)
        .onChange(of: tmapCoordinates.count) { _, _ in
            setInitialCamera()
        }
        // Update target heading when deviceHeading changes
        .onChange(of: deviceHeading) { _, newValue in
            let new = normalizeDeg(newValue ?? targetHeading)
            targetHeading = new
        }
        // 60fps adaptive smoothing (no heavy work each tick)
        .onReceive(Timer.publish(every: 1.0 / fps, on: .main, in: .common).autoconnect()) { _ in
            let delta = shortestDelta(from: smoothHeading, to: targetHeading)
            if abs(delta) < 0.05 {
                smoothHeading = targetHeading
                return
            }
            let alpha = adaptiveAlpha(for: delta)
            smoothHeading = normalizeDeg(smoothHeading + delta * alpha)
        }
    }

    // MARK: - Camera

    private func setInitialCamera() {
        if !tmapCoordinates.isEmpty {
            let poly = MKPolyline(coordinates: tmapCoordinates, count: tmapCoordinates.count)
            let rect = poly.boundingMapRect
            let region = MKCoordinateRegion(rect)
            let center = region.center
            let distance = estimatedDistance(for: rect)

            camera = .camera(MapCamera(centerCoordinate: center,
                                       distance: distance,
                                       heading: 0,
                                       pitch: 55))
        } else if let dest = destination {
            camera = .camera(MapCamera(centerCoordinate: dest,
                                       distance: 900,
                                       heading: 0,
                                       pitch: 55))
        }
    }

    private func estimatedDistance(for rect: MKMapRect) -> CLLocationDistance {
        let midPoint = MKMapPoint(x: rect.midX, y: rect.midY)
        let midCoord = midPoint.coordinate
        let ppm = MKMapPointsPerMeterAtLatitude(midCoord.latitude)
        let widthMeters  = rect.size.width  / ppm
        let heightMeters = rect.size.height / ppm
        let maxSide = max(widthMeters, heightMeters)
        // padding & clamp
        return max(600, min(maxSide * 1.4, 8000))
    }

    // MARK: - Heading smoothing

    private func normalizeDeg(_ x: Double) -> Double {
        var v = x.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    /// a→b shortest turn in [-180, 180]
    private func shortestDelta(from a: Double, to b: Double) -> Double {
        let d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { return d - 360 }
        if d < -180 { return d + 360 }
        return d
    }

    /// Larger delta → faster follow, small jitter → softer
    private func adaptiveAlpha(for delta: Double) -> Double {
        let norm = min(abs(delta) / 90.0, 1.0)     // normalize to [0,1] with ±90° ref
        return baseAlpha + (maxAlpha - baseAlpha) * norm
    }

    // MARK: - Ground puck geometry (in map coordinates)

    private func puckGeometry(center: CLLocationCoordinate2D,
                              heading: CLLocationDirection,
                              r: CLLocationDistance,
                              gap: CLLocationDistance,
                              len: CLLocationDistance,
                              w: CLLocationDistance) -> (center: CLLocationCoordinate2D,
                                                         triangle: [CLLocationCoordinate2D]) {
        // heading: north=0°, clockwise(+)
        let rad = heading * .pi / 180

        // forward (east/north)
        let fx = sin(rad)
        let fy = cos(rad)
        // left perpendicular
        let lx = -fy
        let ly =  fx

        // Offset helper in meters (east, north)
        func offset(from origin: CLLocationCoordinate2D, east: Double, north: Double) -> CLLocationCoordinate2D {
            let R = 6_378_137.0
            let dLat = north / R * 180.0 / .pi
            let dLon = east  / (R * cos(origin.latitude * .pi / 180.0)) * 180.0 / .pi
            return .init(latitude: origin.latitude + dLat, longitude: origin.longitude + dLon)
        }

        // Triangle points
        let baseCenter = offset(from: center, east: (r + gap) * fx, north: (r + gap) * fy)
        let tip        = offset(from: center, east: (r + gap + len) * fx, north: (r + gap + len) * fy)
        let leftBase   = offset(from: baseCenter, east: (w / 2) * lx, north: (w / 2) * ly)
        let rightBase  = offset(from: baseCenter, east: -(w / 2) * lx, north: -(w / 2) * ly)

        return (center, [tip, leftBase, rightBase])
    }
}
