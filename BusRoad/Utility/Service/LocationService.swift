//
//  LocationService.swift
//  BusRoad
//
//  Created by 강진 on 9/28/25.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

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
    func requestOneShotLocation(timeout seconds: TimeInterval = 30) async throws -> CLLocation {
        // 권한 보장
        try await requestWhenInUseAuthorizationIfNeeded()

        // 중복 요청 방지
        guard locationContinuation == nil else {
            throw LocationError.busy
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
                }
            }
        }
    }

    // 좌표만 필요한 경우 편의 메서드
    func requestOneShotCoordinate(timeout seconds: TimeInterval = 30) async throws -> CLLocationCoordinate2D {
        let loc = try await requestOneShotLocation(timeout: seconds)
        return loc.coordinate
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
        // 공개 상태 업데이트 (옵저버들이 사용할 수 있게)
        self.location = loc

        // 대기 중인 1회 요청 완료 처리
        if let cont = locationContinuation {
            cont.resume(returning: loc)
            locationContinuation = nil
        }
        timeoutTask?.cancel()
        timeoutTask = nil
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
