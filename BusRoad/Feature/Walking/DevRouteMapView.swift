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
    let tmapCoordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocation?
    let destination: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // 지도 설정
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // 지도 회전 및 제스처 활성화
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 기존 오버레이 및 어노테이션 제거
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // TMAP 좌표로 폴리라인 생성
        if !tmapCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: tmapCoordinates, count: tmapCoordinates.count)
            mapView.addOverlay(polyline)
            
            // 지도 영역 설정 (경로 전체가 보이도록)
            let rect = polyline.boundingMapRect
            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
                animated: true
            )
        } else if let destination = destination {
            // TMAP 좌표가 없을 때 목적지만 표시
            let annotation = MKPointAnnotation()
            annotation.coordinate = destination
            annotation.title = "목적지"
            mapView.addAnnotation(annotation)
            
            // 현재 위치와 목적지가 보이도록 영역 설정
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
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 사용자 위치는 기본 표시 사용
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "CustomPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 도착지 색상 설정
            if let markerView = annotationView as? MKMarkerAnnotationView {
                if annotation.title == "도착지" {
                    markerView.markerTintColor = .systemRed
                    markerView.glyphImage = UIImage(systemName: "flag.fill")
                } else {
                    markerView.markerTintColor = .systemBlue
                }
            }
            
            return annotationView
        }
    }
}
