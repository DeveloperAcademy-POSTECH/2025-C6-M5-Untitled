//
//  User.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import Foundation
import CoreLocation

struct User{
    var currentLocation: CLLocationCoordinate2D?
    var selectedRoute: BusRoute?
    
    /// 현재 버스에 탑승 중인지 여부
    var isOnBus: Bool
    
    /// 현재 탑승 중인 버스 번호
    var currentBusNumber: String?
    
    /// 다음 하차 정류장 이름
    var nextAlightingStop: String?
    
    /// 다음 환승을 위해 탑승할 정류장 이름
    var nextBoardingStop: String?
}
