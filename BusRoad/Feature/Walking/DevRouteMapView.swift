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
                    animated: true
                )
                context.coordinator.hasSetInitialRegion = true
            }
        } else if let dest = destination, context.coordinator.hasSetInitialRegion == false {
            // 경로가 없을 때만 목적지 핀을 간단히 표시
            let region = MKCoordinateRegion(center: dest, latitudinalMeters: 900, longitudinalMeters: 900)
            mapView.setRegion(region, animated: true)
            let ann = MKPointAnnotation()
            ann.coordinate = dest
            ann.title = "목적지"
            mapView.addAnnotation(ann)
            context.coordinator.hasSetInitialRegion = true
        }
        
        // 사용자 puck 회전 갱신 (지도 카메라 회전 보정)
        context.coordinator.applyHeading(deviceHeading, on: mapView)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate {
        var hasSetInitialRegion = false
        private weak var puckView: UserPuckView?
        
        // 경로 렌더러
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: poly)
            r.strokeColor = .systemBlue
            r.lineWidth = 5
            r.lineCap = .round
            r.lineJoin = .round
            return r
        }
        
        // 사용자 위치만 커스텀. 그 외(목적지)는 기본 마커.
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
        
        // 지도가 회전하면 보정 필요
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            applyHeading(nil, on: mapView)
        }
        
        // 기기 헤딩(옵션) + 지도 회전 보정 적용
        func applyHeading(_ deviceHeading: CLLocationDirection?, on mapView: MKMapView) {
            let mapHeading = mapView.camera.heading
            let dev = deviceHeading ?? 0
            let visual = CGFloat((dev - mapHeading).truncatingRemainder(dividingBy: 360))
            puckView?.setHeading(visualDegrees: visual)
        }
    }
}

// MARK: - SwiftUI로 그린 puck (원 + 위쪽 삼각형)
private struct PuckGlyph: View {
    let diameter: CGFloat
    let arrowWidth: CGFloat
    let arrowHeight: CGFloat
    let gap: CGFloat

    var body: some View {
        let totalH = diameter + gap + arrowHeight
        let totalW = max(diameter, arrowWidth)

        ZStack {
            // 원: 파랑 채움 + 흰색 테두리 (가독성)
            Circle()
                .fill(Color.blue)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle().stroke(Color.primarywhite, lineWidth: 2)
                )

            // 삼각형: 파랑
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
    
    // 디자인 파라미터 (필요시 숫자만 조절)
    private let diameter: CGFloat = 22
    private let arrowWidth: CGFloat = 10
    private let arrowHeight: CGFloat = 8
    private let gap: CGFloat = 12   // 원 밖으로 살짝 띄우는 간격
    
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
        
        // 부드러운 그림자
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }
    
    /// 북(0°) 기준 시계방향. 지도 카메라 보정 포함 각도.
    func setHeading(visualDegrees: CGFloat) {
        let rad = visualDegrees * .pi / 180
        hosting?.view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        hosting?.view.layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        hosting?.view.transform = CGAffineTransform(rotationAngle: rad)
    }
}
