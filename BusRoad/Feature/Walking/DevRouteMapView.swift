//
//  DevRouteMapView.swift
//  BusRoad
//
//  Created by 박난 on 10/24/25.
//

// [CHECK] 개발자용 맵 뷰
import MapKit
import SwiftUI

struct DevRouteMapView: UIViewRepresentable {
    var route: MKRoute?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        if let route = route {
            mapView.addOverlay(route.polyline)
            let rect = route.polyline.boundingMapRect
            mapView.setVisibleMapRect(rect,
                                      edgePadding: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30),
                                      animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

