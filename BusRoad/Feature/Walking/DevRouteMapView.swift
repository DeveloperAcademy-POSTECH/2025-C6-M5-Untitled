import MapKit
import SwiftUI

struct DevRouteMapView: UIViewRepresentable {
    let tmapCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let destination: CLLocationCoordinate2D?
    let deviceHeading: CLLocationDirection?
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .none
        
        map.mapType = .standard
        map.showsCompass = true
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        
        // 살짝 더 입체감 있는 타일
        let cfg = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        map.preferredConfiguration = cfg
        map.showsBuildings = true
        
        return map
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 경로 갱신
        mapView.removeOverlays(mapView.overlays)
        if !tmapCoordinates.isEmpty {
            let poly = MKPolyline(coordinates: tmapCoordinates, count: tmapCoordinates.count)
            mapView.addOverlay(poly)
            
            if context.coordinator.hasSetInitialRegion == false {
                mapView.setVisibleMapRect(
                    poly.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
                    animated: false
                )
                context.coordinator.hasSetInitialRegion = true
                // 프레이밍이 끝난 "다음 프레임"에 피치만 주입 (거리/중심은 그대로)
                context.coordinator.applyInitialPitchLater(on: mapView)
            }
        } else if let dest = destination, context.coordinator.hasSetInitialRegion == false {
            mapView.setRegion(
                MKCoordinateRegion(center: dest, latitudinalMeters: 900, longitudinalMeters: 900),
                animated: false
            )
            let ann = MKPointAnnotation()
            ann.coordinate = dest
            ann.title = "목적지"
            mapView.addAnnotation(ann)
            context.coordinator.hasSetInitialRegion = true
            context.coordinator.applyInitialPitchLater(on: mapView)
        }
        
        // 사용자 puck 회전 갱신 (지도 카메라 회전 보정)
        context.coordinator.applyHeading(deviceHeading, on: mapView)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate {
        var hasSetInitialRegion = false
        private weak var puckView: UserPuckView?
        private let defaultPitch: CGFloat = 55
        private var didInjectInitialPitch = false  // 초기 1회만 피치 주입
        
        // 경로 렌더러 (경로 = 파랑)
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: poly)
            r.strokeColor = .systemBlue
            r.lineWidth = 5
            r.lineCap = .round
            r.lineJoin = .round
            return r
        }
        
        // 사용자 위치만 커스텀 puck 사용
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let id = "UserPuck"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? UserPuckView
                if view == nil {
                    view = UserPuckView(annotation: annotation, reuseIdentifier: id)
                } else {
                    view?.annotation = annotation
                }
                puckView = view
                return view
            }
            return nil
        }
        
        // 사용자가 손댄 후에도 “피치만” 살짝 유지하고, 축소 제한은 두지 않음
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if didInjectInitialPitch, mapView.camera.pitch < defaultPitch - 1 {
                var cam = mapView.camera
                cam.pitch = defaultPitch     // 거리/중심은 그대로 유지
                mapView.setCamera(cam, animated: false)
            }
            applyHeading(nil, on: mapView)
        }
        
        /// 프레이밍이 완료된 다음 프레임에 피치만 주입 (거리/중심 유지)
        func applyInitialPitchLater(on mapView: MKMapView) {
            guard didInjectInitialPitch == false else { return }
            didInjectInitialPitch = true
            DispatchQueue.main.async {
                var cam = mapView.camera
                cam.pitch = self.defaultPitch
                mapView.setCamera(cam, animated: false)
                
                // 줌 제한 제거
                mapView.setCameraZoomRange(nil, animated: false)
            }
        }
        
        /// 기기 헤딩(옵션) + 지도 카메라 회전 보정 적용
        func applyHeading(_ deviceHeading: CLLocationDirection?, on mapView: MKMapView) {
            let mapHeading = mapView.camera.heading
            let dev = deviceHeading ?? 0
            var vis = (dev - mapHeading).truncatingRemainder(dividingBy: 360)
            if vis < 0 { vis += 360 }
            puckView?.setHeading(visualDegrees: CGFloat(vis))
        }
    }
}

// MARK: - SwiftUI로 그린 puck (원 + 위쪽 삼각형) — 경로색(파랑)과 통일
private struct PuckGlyph: View {
    let diameter: CGFloat
    let arrowWidth: CGFloat
    let arrowHeight: CGFloat
    let gap: CGFloat
    
    var body: some View {
        let totalH = diameter + gap + arrowHeight
        let totalW = max(diameter, arrowWidth)
        
        ZStack {
            // 원: 경로색(파랑) + 흰색 테두리
            Circle()
                .fill(Color.blue)
                .frame(width: diameter, height: diameter)
                .overlay(Circle().stroke(Color.primarywhite, lineWidth: 2))
            
            // 삼각형: 경로색(파랑)
            ArrowUp()
                .fill(Color.blue)
                .overlay(ArrowUp().stroke(Color.primarywhite, lineWidth: 1))
                .frame(width: arrowWidth, height: arrowHeight)
                .offset(y: -(diameter/2 + gap) + arrowHeight/2)
        }
        .frame(width: totalW, height: totalH)
        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
    }
}

private struct ArrowUp: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        p.move(to: CGPoint(x: midX, y: rect.minY))
        p.addLine(to: CGPoint(x: midX - rect.width/2, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX + rect.width/2, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - MKAnnotationView hosting SwiftUI puck
private final class UserPuckView: MKAnnotationView {
    private var hosting: UIHostingController<PuckGlyph>?
    
    // 디자인 파라미터
    private let diameter: CGFloat = 22
    private let arrowWidth: CGFloat = 10
    private let arrowHeight: CGFloat = 8
    private let gap: CGFloat = 12
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    
    private func setup() {
        let totalH = diameter + gap + arrowHeight
        let totalW = max(diameter, arrowWidth)
        
        bounds = CGRect(x: 0, y: 0, width: totalW, height: totalH)
        centerOffset = .zero
        displayPriority = .required
        collisionMode = .circle
        clipsToBounds = false
        
        let glyph = PuckGlyph(
            diameter: diameter,
            arrowWidth: arrowWidth,
            arrowHeight: arrowHeight,
            gap: gap
        )
        let host = UIHostingController(rootView: glyph)
        host.view.backgroundColor = .clear
        host.view.frame = bounds
        addSubview(host.view)
        hosting = host
    }
    
    /// 북(0°) 기준 시계방향. 지도 카메라 보정 포함 각도.
    func setHeading(visualDegrees: CGFloat) {
        let rad = visualDegrees * .pi / 180
        if let hostingView = hosting?.view {
            hostingView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            hostingView.layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            hostingView.transform = CGAffineTransform(rotationAngle: rad)
        }
    }
}
