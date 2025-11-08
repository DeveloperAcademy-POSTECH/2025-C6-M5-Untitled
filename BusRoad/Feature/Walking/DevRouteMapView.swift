import MapKit
import SwiftUI

struct DevRouteMapView: UIViewRepresentable {
    let tmapCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let destination: CLLocationCoordinate2D?
    let deviceHeading: CLLocationDirection?   // 선택: 현재 기기 헤딩 디버깅용
    
    // ✅ 포인트 뿌리기 옵션
    var showRoutePoints: Bool = true
    var maxPointAnnotations: Int = 400   // 너무 많으면 자동 샘플링
    var pointSize: CGFloat = 6
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        
        // 디버그 라벨
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        mapView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: mapView.leadingAnchor, constant: 12),
            label.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 12),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 280)
        ])
        context.coordinator.infoLabel = label
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 사용자 위치/헤딩 어노테이션은 남겨두고 나머지 제거
        let keep = Set(mapView.annotations.compactMap { $0 as? MKUserLocation }) // MKUserLocation만 유지
        let headingAnn = context.coordinator.headingAnnotation
        var toRemove = mapView.annotations.filter { ann in
            if let user = ann as? MKUserLocation { return !keep.contains(user) }
            if let heading = headingAnn, ann === heading { return false }
            return true
        }
        if toRemove.isEmpty == false { mapView.removeAnnotations(toRemove) }
        if mapView.overlays.isEmpty == false { mapView.removeOverlays(mapView.overlays) }
        
        // 폴리라인
        if !tmapCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: tmapCoordinates, count: tmapCoordinates.count)
            mapView.addOverlay(polyline)
            
            // ✅ 포인트 찍기
            if showRoutePoints {
                let stride = samplingStride(total: tmapCoordinates.count, maxSamples: maxPointAnnotations)
                var annotations: [MKAnnotation] = []
                for (i, coord) in tmapCoordinates.enumerated() where i % stride == 0 {
                    let ann = RoutePointAnnotation(coordinate: coord, index: i)
                    annotations.append(ann)
                }
                // 시작/끝은 구분
                if let first = tmapCoordinates.first {
                    annotations.append(EndpointAnnotation(coordinate: first, kind: .start))
                }
                if let last = tmapCoordinates.last {
                    annotations.append(EndpointAnnotation(coordinate: last, kind: .end))
                }
                mapView.addAnnotations(annotations)
            }
            
            // 최초 1회만 카메라 세팅
            if context.coordinator.hasSetInitialRegion == false {
                let rect = polyline.boundingMapRect
                mapView.setVisibleMapRect(
                    rect,
                    edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
                    animated: true
                )
                context.coordinator.hasSetInitialRegion = true
            }
        } else if let destination = destination {
            // 경로 없으면 목적지만
            let annotation = EndpointAnnotation(coordinate: destination, kind: .end)
            mapView.addAnnotation(annotation)
            
            if context.coordinator.hasSetInitialRegion == false {
                if let userLoc = userLocation {
                    let coordinates = [userLoc.coordinate, destination]
                    let rect = MKPolyline(coordinates: coordinates, count: 2).boundingMapRect
                    mapView.setVisibleMapRect(
                        rect,
                        edgePadding: UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
                        animated: true
                    )
                } else {
                    let region = MKCoordinateRegion(
                        center: destination,
                        latitudinalMeters: 1000,
                        longitudinalMeters: 1000
                    )
                    mapView.setRegion(region, animated: true)
                }
                context.coordinator.hasSetInitialRegion = true
            }
        }
        
        // 헤딩 화살표
        if let loc = userLocation {
            context.coordinator.updateHeadingAnnotation(
                on: mapView,
                at: loc.coordinate,
                heading: deviceHeading
            )
        } else {
            context.coordinator.removeHeadingAnnotation(from: mapView)
        }
        
        // 디버그 텍스트
        let headingText = deviceHeading.map { String(format: "%.0f°", $0) } ?? "--"
        let userText: String = {
            guard let loc = userLocation else { return "user: --" }
            return String(format: "user: %.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude)
        }()
        let destText: String = {
            guard let dst = destination else { return "dest: --" }
            return String(format: "dest: %.5f, %.5f", dst.latitude, dst.longitude)
        }()
        let countText = "route pts: \(tmapCoordinates.count)"
        context.coordinator.infoLabel?.text =
        """
        heading: \(headingText)
        \(userText)
        \(destText)
        \(countText)
        """
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(pointSize: pointSize) }
    
    // 샘플링 stride 계산
    private func samplingStride(total: Int, maxSamples: Int) -> Int {
        guard total > 0 else { return 1 }
        if total <= maxSamples { return 1 }
        let stride = Int(ceil(Double(total) / Double(maxSamples)))
        return max(1, stride)
    }
    
    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate {
        var hasSetInitialRegion = false
        weak var infoLabel: UILabel?
        fileprivate var headingAnnotation: MKPointAnnotation?
        private let pointSize: CGFloat
        
        init(pointSize: CGFloat) {
            self.pointSize = pointSize
            super.init()
        }
        
        // 폴리라인 렌더러
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // 어노테이션 뷰
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            // 헤딩 화살표
            if let heading = headingAnnotation, annotation === heading {
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: HeadingAnnotationView.reuseID) as? HeadingAnnotationView
                if view == nil {
                    view = HeadingAnnotationView(annotation: annotation, reuseIdentifier: HeadingAnnotationView.reuseID)
                } else {
                    view?.annotation = annotation
                }
                return view
            }
            
            // 시작/끝 핀
            if let end = annotation as? EndpointAnnotation {
                let id = "Endpoint"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = annotation
                }
                if let mv = view {
                    switch end.kind {
                    case .start:
                        mv.markerTintColor = .systemGreen
                        mv.glyphImage = UIImage(systemName: "play.fill")
                        mv.titleVisibility = .visible
                        mv.subtitleVisibility = .hidden
                    case .end:
                        mv.markerTintColor = .systemRed
                        mv.glyphImage = UIImage(systemName: "flag.fill")
                        mv.titleVisibility = .visible
                        mv.subtitleVisibility = .hidden
                    }
                }
                return view
            }
            
            // ✅ 경로 포인트(작은 점)
            if annotation is RoutePointAnnotation {
                let id = "RoutePointDot"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? DotAnnotationView
                if view == nil {
                    view = DotAnnotationView(annotation: annotation, reuseIdentifier: id, size: pointSize)
                } else {
                    view?.annotation = annotation
                }
                return view
            }
            
            return nil
        }
        
        // MARK: Heading annotation control
        func updateHeadingAnnotation(on mapView: MKMapView,
                                     at coordinate: CLLocationCoordinate2D,
                                     heading: CLLocationDirection?) {
            if headingAnnotation == nil {
                let ann = MKPointAnnotation()
                ann.coordinate = coordinate
                ann.title = "heading"
                headingAnnotation = ann
                mapView.addAnnotation(ann)
            } else {
                headingAnnotation?.coordinate = coordinate
            }
            if let ann = headingAnnotation,
               let view = mapView.view(for: ann) as? HeadingAnnotationView,
               let deg = heading {
                let rad = CGFloat(deg * .pi / 180.0)
                view.transform = CGAffineTransform(rotationAngle: rad)
            }
        }
        
        func removeHeadingAnnotation(from mapView: MKMapView) {
            if let ann = headingAnnotation {
                mapView.removeAnnotation(ann)
                headingAnnotation = nil
            }
        }
        
        // MARK: - Custom Views/Annotations
        // 헤딩 화살표
        private class HeadingAnnotationView: MKAnnotationView {
            static let reuseID = "HeadingAnnotationView"
            override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
                super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
                setup()
            }
            required init?(coder: NSCoder) {
                super.init(coder: coder); setup()
            }
            private func setup() {
                let img = UIImage(systemName: "location.north.fill")?
                    .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
                image = img
                bounds = CGRect(x: 0, y: 0, width: 28, height: 28)
                centerOffset = CGPoint(x: 0, y: -14)
            }
        }
        
        // 작은 점(원형) 어노테이션 뷰
        private class DotAnnotationView: MKAnnotationView {
            init(annotation: MKAnnotation?, reuseIdentifier: String?, size: CGFloat) {
                super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
                let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circle.backgroundColor = UIColor.systemBlue
                circle.layer.cornerRadius = size / 2
                circle.layer.borderWidth = 1
                circle.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
                UIGraphicsBeginImageContextWithOptions(circle.bounds.size, false, 0.0)
                if let ctx = UIGraphicsGetCurrentContext() {
                    circle.layer.render(in: ctx)
                }
                let img = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                self.image = img
                self.bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
                self.centerOffset = CGPoint(x: 0, y: 0)
            }
            required init?(coder: NSCoder) { super.init(coder: coder) }
        }
    }
}

// MARK: - Annotation Types
private final class RoutePointAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let index: Int
    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.index = index
        super.init()
    }
}

private final class EndpointAnnotation: NSObject, MKAnnotation {
    enum Kind { case start, end }
    dynamic var coordinate: CLLocationCoordinate2D
    let kind: Kind
    var title: String? {
        switch kind {
        case .start: return "출발"
        case .end:   return "도착"
        }
    }
    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
        super.init()
    }
}
