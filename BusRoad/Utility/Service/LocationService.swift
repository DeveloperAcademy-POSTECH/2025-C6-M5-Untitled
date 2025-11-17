//
//  LocationService.swift
//  BusRoad
//
//  Created by 강진 on 9/28/25.
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = LocationService()

    // Errors
    enum LocationError: LocalizedError {
        case servicesDisabled
        case authorizationDenied
        case timeout
        case busy
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .servicesDisabled:   return "위치 서비스가 비활성화되어 있습니다."
            case .authorizationDenied:return "위치 권한이 거부/제한되었습니다."
            case .timeout:            return "위치 정보를 가져오는 데 시간이 초과되었습니다."
            case .busy:               return "이미 위치 요청이 진행 중입니다."
            case .unknown:            return "알 수 없는 오류가 발생했습니다."
            }
        }
    }
    
    // MARK: - Public State
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    
    // MARK: - Private
    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?
    
    // MARK: - Init
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        // 백그라운드 업데이트 허용
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .otherNavigation
    }
    
    // MARK: - Public API
    
    // 권한이 없으면 요청하고, 승인/거절 결과를 async로 대기
    func requestWhenInUseAuthorizationIfNeeded() async throws {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.servicesDisabled
        }
        
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return
            
        case .notDetermined:
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                self.authContinuation = cont
                // 권한 요청은 메인에서 (UI 프롬프트 표시를 위한 권장 경로)
                DispatchQueue.main.async { [weak self] in
                    self?.manager.requestWhenInUseAuthorization()
                }
            }
            
        case .restricted, .denied:
            throw LocationError.authorizationDenied
            
        @unknown default:
            throw LocationError.unknown
        }
    }
    
    
    // 1회성 현재 위치 가져오기 (권한 체크 포함). 기본 타임아웃 8초.
    func requestOneShotLocation(timeout seconds: TimeInterval = 5) async throws -> CLLocation {
        // 권한 보장
        try await requestWhenInUseAuthorizationIfNeeded()
        
        // 기존 요청이 있다면 강제 종료(웜업 진행중일 가능성)
        if let cont = locationContinuation {
            cont.resume(throwing: LocationError.busy)
            locationContinuation = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            print("[LocationService] 기존 위치 요청 중단됨 (새 요청으로 교체)")
        }
        
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CLLocation, Error>) in
            // 위치 요청 시작
            self.locationContinuation = cont
            self.manager.requestLocation()
            
            // 타임아웃 태스크 설정
            self.timeoutTask?.cancel()
            self.timeoutTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if let cont = self.locationContinuation {
                    cont.resume(throwing: LocationError.timeout)
                    self.locationContinuation = nil
                    print("[LocationService] 위치 요청 타임아웃")
                }
            }
        }
    }

    
    // 좌표만 필요한 경우 편의 메서드
    func requestOneShotCoordinate(timeout seconds: TimeInterval = 5) async throws -> CLLocationCoordinate2D {
        let loc = try await requestOneShotLocation(timeout: seconds)
        return loc.coordinate
    }
    
    // 캐시 우선 빠른 위치 가져오기
    func getQuickLocation(maxAge: TimeInterval = 300) async throws -> CLLocation {
        // 최근 위치가 있으면 즉시 반환
        if let cached = location,
           Date().timeIntervalSince(cached.timestamp) < maxAge {
            print("[LocationService] 캐시된 위치 사용 (시간: \(Int(Date().timeIntervalSince(cached.timestamp)))초)")
            return cached
        }
        
        // 캐시 없으면 새로 요청 (타임아웃 늘림)
        print("[LocationService] 새 위치 요청")
        return try await requestOneShotLocation(timeout: 10)
    }
    
    // 좌표만 필요한 경우
    func getQuickCoordinate(maxAge: TimeInterval = 300) async throws -> CLLocationCoordinate2D {
        let loc = try await getQuickLocation(maxAge: maxAge)
        return loc.coordinate
    }
    
    // 앱 시작 시 백그라운드 트래킹 시작
    func startLightTracking() async throws {
        try await requestWhenInUseAuthorizationIfNeeded()
        
        manager.distanceFilter = 100  // 100m마다 업데이트
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.allowsBackgroundLocationUpdates = false  // 백그라운드 끄기
        manager.pausesLocationUpdatesAutomatically = true  // 자동 일시정지
        manager.activityType = .otherNavigation  // 네비게이션 최적화
        
        manager.startUpdatingLocation()
        print("[LocationService] 백그라운드 트래킹 시작 (포그라운드 전용)")
    }
    
    func forceRefreshLocation(timeout seconds: TimeInterval = 15) async throws -> CLLocation {
        print("[LocationService] 🔄 강제 새로고침 시작")
        
        // 권한 보장
        try await requestWhenInUseAuthorizationIfNeeded()
        
        // 기존 연속 업데이트 중지 (충돌 방지)
        manager.stopUpdatingLocation()
        
        // 기존 요청이 있다면 취소
        if let cont = locationContinuation {
            cont.resume(throwing: LocationError.busy)
            locationContinuation = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            print("[LocationService] 기존 위치 요청 중단됨")
        }
        
        // 정확도를 최대로 설정
        let previousAccuracy = manager.desiredAccuracy
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CLLocation, Error>) in
            self.locationContinuation = cont
            
            // requestLocation() 대신 startUpdatingLocation() 사용
            self.manager.startUpdatingLocation()
            
            // 타임아웃 설정
            self.timeoutTask?.cancel()
            self.timeoutTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                
                await MainActor.run {
                    if let cont = self.locationContinuation {
                        self.manager.stopUpdatingLocation()
                        self.manager.desiredAccuracy = previousAccuracy
                        cont.resume(throwing: LocationError.timeout)
                        self.locationContinuation = nil
                        print("[LocationService] ⏱️ 위치 요청 타임아웃")
                    }
                }
            }
        }
    }
    
    // 캐시 위치 무효
    func invalidateCache() {
        self.location = nil
        print("[LocationService] 위치 캐시 무효화됨")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authContinuation?.resume()
            authContinuation = nil
        case .restricted, .denied:
            authContinuation?.resume(throwing: LocationError.authorizationDenied)
            authContinuation = nil
        case .notDetermined:
            // 아직 결정되지 않음 → 아무 것도 하지 않음
            break
        @unknown default:
            authContinuation?.resume(throwing: LocationError.unknown)
            authContinuation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        // 공개 상태 업데이트
        self.location = loc
        
        print("[LocationService] 📍 위치 업데이트: \(loc.coordinate.latitude), \(loc.coordinate.longitude), 정확도: \(loc.horizontalAccuracy)m")
        
        // 대기 중인 1회 요청 완료 처리
        if let cont = locationContinuation {
            // 정확도가 충분한 위치만 반환
            if loc.horizontalAccuracy > 0 && loc.horizontalAccuracy <= 100 {
                manager.stopUpdatingLocation()  // ⭐ 중요: 업데이트 중지
                cont.resume(returning: loc)
                locationContinuation = nil
                timeoutTask?.cancel()
                timeoutTask = nil
                print("[LocationService] ✅ 위치 요청 완료 (정확도: \(loc.horizontalAccuracy)m)")
            } else {
                print("[LocationService] ⚠️ 정확도 불충분 (\(loc.horizontalAccuracy)m), 계속 대기...")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let cont = locationContinuation {
            cont.resume(throwing: error)
            locationContinuation = nil
        }
        timeoutTask?.cancel()
        timeoutTask = nil
        print("🚨 위치 실패: \(error.localizedDescription)")
    }
}

// 실시간 위치추적 기능
// TODO: - extension 파일 추후 분리해야함
extension LocationService {
    func startContinuousUpdates(
        // 10m 이동마다 업데이트되도록
        distanceFilter: CLLocationDistance = 10,
        accuracy: CLLocationAccuracy = kCLLocationAccuracyBest,
        allowsBackgroundUpdates: Bool = true  // 백그라운드 옵션
    ) async throws {
        try await requestWhenInUseAuthorizationIfNeeded()
        
        manager.distanceFilter = distanceFilter
        manager.desiredAccuracy = accuracy
        manager.pausesLocationUpdatesAutomatically = false  // 계속 추적
        manager.allowsBackgroundLocationUpdates = allowsBackgroundUpdates  // 백그라운드 설정
        manager.activityType = .otherNavigation
        
        manager.startUpdatingLocation()
        print("[LocationService] 연속 위치 업데이트 시작 (백그라운드: \(allowsBackgroundUpdates))")
    }
    
    func stopContinuousUpdates() {
        manager.stopUpdatingLocation()
    }
}
