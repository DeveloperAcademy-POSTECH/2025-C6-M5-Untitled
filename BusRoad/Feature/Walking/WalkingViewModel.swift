import SwiftUI
import Combine
import MapKit
import CoreLocation

final class WalkingViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  
  // MARK: - UI 상태
  @Published var bigDistanceText: String = "-- m"           // 중앙 거리 표시
  @Published var arrowBearing: CLLocationDirection = 0       // 화살표 방향
  @Published var nextCards: [String] = []                   // 다음 스텝 카드 목록
  @Published var arrived: Bool = false
  // 도착 여부 확인
  
  
  // MARK: - 내부 상태
  private let loc = CLLocationManager()
  private var route: MKRoute?
  private var stepIndex: Int = 0
  private var pendingDestination: CLLocationCoordinate2D?
  private var hasCalculatedRoute = false
  private var lastRemain: CLLocationDistance?
  
  // 스텝 전환 거리 임계값
  var stepSwitchDistance: CLLocationDistance = 6
  
  override init() {
    super.init()
    loc.delegate = self
    loc.desiredAccuracy = kCLLocationAccuracyBest
    loc.headingFilter = 1 // 최소 1도 변화 시 업데이트
    loc.headingOrientation = .portrait // 세로 모드 기준
  }
  
  // MARK: - Public
  func start() {
    loc.requestWhenInUseAuthorization()
    loc.startUpdatingLocation()
    loc.startUpdatingHeading()
  }
  
  func setDestination(_ dest: CLLocationCoordinate2D) {
    resetRouteState()
    pendingDestination = dest
    tryCalculateIfReady()
  }
  
  private func resetRouteState() {
      self.route = nil
      self.stepIndex = 0
      self.hasCalculatedRoute = false // 경로 계산 플래그 리셋
      self.bigDistanceText = "-- m"
      self.arrowBearing = 0
      self.arrived = false
      self.nextCards = []
  }

  func setDestination(from node: WalkRouteNode) {
    let coordinate = CLLocationCoordinate2D(latitude: node.end.latitude, longitude: node.end.longitude)
    setDestination(coordinate)
  }
  
  // MARK: - 경로 계산
  private func tryCalculateIfReady() {
    guard !hasCalculatedRoute,
          let origin = loc.location?.coordinate,
          let dest = pendingDestination else { return }
    hasCalculatedRoute = true
    calculateRoute(origin: origin, dest: dest)
  }
  
  private func calculateRoute(origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) {
    let req = MKDirections.Request()
    req.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
    req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
    req.transportType = .walking
    
    MKDirections(request: req).calculate { [weak self] resp, err in
      guard let self = self else { return }
      if let err = err {
        print("Route error:", err.localizedDescription)
        self.bigDistanceText = "경로 계산 실패"
        return
      }
      guard let r = resp?.routes.first else {
        self.bigDistanceText = "경로 없음"
        return
      }
      self.route = r
      self.stepIndex = 0
      self.rebuildNextCards()
    }
  }
  
  // MARK: - 스텝 카드 업데이트
  private func rebuildNextCards() {
    guard let r = route else {
      nextCards = []
      return
    }
    let upcoming = r.steps.dropFirst(stepIndex).prefix(3)
    nextCards = upcoming.map { step in
      let d = Int(step.distance.rounded())
      let turn = inferTurnText(for: step)
      return "\(turn) \(d)m"
    }
  }
  
  private func inferTurnText(for step: MKRoute.Step) -> String {
    let ins = step.instructions.lowercased()
    if ins.contains("left") || ins.contains("좌") { return "좌회전" }
    if ins.contains("right") || ins.contains("우") { return "우회전" }
    if ins.contains("u-turn") || ins.contains("유턴") { return "유턴" }
    return "직진"
  }
  
  // MARK: - 실시간 위치 업데이트
  private func updateWith(location: CLLocation, heading: CLHeading?) {
    guard let r = route, stepIndex < r.steps.count else {
      bigDistanceText = "-- m"
      return
    }

    guard location.horizontalAccuracy < 50 else { return }

    let step = r.steps[stepIndex]

    // 1) 현재 스텝에서 남은 거리 계산
    let (progress, remain) = progressOn(step.polyline, user: location)
    if remain >= stepSwitchDistance {
        bigDistanceText = "\(Int(remain)) m"
    } else {
        arrived = true
    }

    // 2) 목표 방향과 기기 방향 비교 → 화살표 회전
    if let headingValue = heading?.trueHeading, headingValue >= 0,
       let dest = pendingDestination {
        let userCoord = location.coordinate
        let targetCoord = dest
        let segmentBearing = bearing(from: userCoord, to: targetCoord)
        // 상대 각도 (목표방향 - 현재 기기방향)
        let relative = (segmentBearing - headingValue + 360).truncatingRemainder(dividingBy: 360)
        arrowBearing = relative
    }

    // 3) 스텝 전환
    if remain < stepSwitchDistance {
      let oldIndex = stepIndex
      stepIndex = min(stepIndex + 1, r.steps.count - 1)
      if stepIndex != oldIndex { rebuildNextCards() }
    }
  }
  
  // MARK: - CLLocationManagerDelegate
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      manager.startUpdatingLocation()
      manager.startUpdatingHeading()
      tryCalculateIfReady()
    default:
      break
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    // 방향 업데이트 시
    if let loc = manager.location {
      updateWith(location: loc, heading: newHeading)
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let last = locations.last else { return }
    updateWith(location: last, heading: manager.heading)
    tryCalculateIfReady()
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Location error:", error.localizedDescription)
  }
  
  // MARK: - 거리 및 진행률 계산
  private func progressOn(_ polyline: MKPolyline, user: CLLocation)
  -> (Double, CLLocationDistance) {
    guard let dest = pendingDestination else {
      return (0, 0)
    }
    let remain = CLLocation(latitude: dest.latitude, longitude: dest.longitude).distance(from: user)
    return (0, remain)
  }
  
  // 사용자 위치를 세그먼트에 투영
  private func project(_ p: CLLocationCoordinate2D,
                       _ a: CLLocationCoordinate2D,
                       _ b: CLLocationCoordinate2D,
                       segTotal: CLLocationDistance) -> (CLLocationCoordinate2D, CLLocationDistance) {
    
    let mp = MKMapPoint(p)
    let ma = MKMapPoint(a)
    let mb = MKMapPoint(b)
    
    let abx = mb.x - ma.x
    let aby = mb.y - ma.y
    let apx = mp.x - ma.x
    let apy = mp.y - ma.y
    
    let ab2 = abx*abx + aby*aby
    let t = ab2 > 0 ? max(0, min(1, (apx*abx + apy*aby) / ab2)) : 0
    
    let proj = MKMapPoint(x: ma.x + abx * t, y: ma.y + aby * t).coordinate
    let along = segTotal * CLLocationDistance(t)
    return (proj, along)
  }
  
  // 경로 방향 계산
  private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
    let φ1 = from.latitude * .pi/180, φ2 = to.latitude * .pi/180
    let deltaLambda = (to.longitude - from.longitude) * .pi/180
    let y = sin(deltaLambda) * cos(φ2)
    let x = cos(φ1)*sin(φ2) - sin(φ1)*cos(φ2)*cos(deltaLambda)
    let θ = atan2(y, x) * 180 / .pi
    return fmod(θ + 360, 360)
  }
  
  // 다음 세그먼트의 목표 방향
  private func forwardBearing(on polyline: MKPolyline,
                              user: CLLocation,
                              fallbackToHeading: CLLocationDirection) -> CLLocationDirection? {
    let n = polyline.pointCount
    guard n >= 2 else { return fallbackToHeading }
    let pts = polyline.points()
    
    var bestIdx = 0
    var bestDist = CLLocationDistance.greatestFiniteMagnitude
    
    for i in 0..<(n-1) {
      let a = pts[i].coordinate
      let b = pts[i+1].coordinate
      
      let ma = MKMapPoint(a)
      let mb = MKMapPoint(b)
      let segTotal = ma.distance(to: mb)
      
      let (proj, _) = project(user.coordinate, a, b, segTotal: segTotal)
      let d = CLLocation(latitude: proj.latitude, longitude: proj.longitude)
        .distance(from: user)
      if d < bestDist {
        bestDist = d
        bestIdx = i
      }
    }
    
    let a = pts[bestIdx].coordinate
    let b = pts[min(bestIdx+1, n-1)].coordinate
    return bearing(from: a, to: b)
  }
}
