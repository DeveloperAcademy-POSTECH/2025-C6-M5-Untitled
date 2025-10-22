//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct BeforeRideView: View {
    @StateObject private var viewmodel = BeforeRideViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    var journey: Journey?
    var index: Int?
    
    init(manager: JourneyManager = .shared) {   // TODO: 의존성 문제 해결(manager viewModel로 빼기)
        if let journey = manager.selectedJourney, let index = manager.journeyIndex {
            self.journey = journey
            self.index = index
        }
    }
    
    var body: some View {
        
        ZStack {
            Color.primarywhite
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                VStack(spacing: 0) {
                    
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                       
                    
                    if let journey, let index {
                        WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: true)
                            .padding(32)
                    }
                    
                }
                .frame(height: 144)
                
                LineDivider()
                
                ZStack {
                    Color(.background)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        if let journey, let index, case let .bus(busNode) = journey.nodes[index] {
                            BeforeRideCard(
                                waitingStopName: busNode.stations[0].stationName,
                                waitingBusNO: busNode.busNo,
                                remainingStopsToBoarding: .constant(1),
                                remainingTimeToBoarding: 1
                            )
                            .padding(.horizontal, 24.wScaled)
                            .padding(.top, 28.wScaled)
                            .padding(.bottom, 47.wScaled)
                        }
                        
                        Button {
                            coordinator.advanceJourneyStage()
                        } label: {
                            Text("탔어요")
                                .font(.premed32)
                                .foregroundStyle(.subLight)
                                .frame(width: 239, height: 74)
                                .background(.subStrong)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .frame(height: 74)
                    }
                }
            }
        }
    }
}

#Preview {
    let manager = JourneyManager.shared
    
    // 정류장들
    let station1 = BusStation(index: 0, stationId: 1001, stationName: "포항공대 정문", stationCityCode: 37010, localStationId: "101")
    let station2 = BusStation(index: 1, stationId: 1002, stationName: "죽도시장", stationCityCode: 37010, localStationId: "102")
    let station3 = BusStation(index: 2, stationId: 1003, stationName: "포항역", stationCityCode: 37010, localStationId: "103")
    let station4 = BusStation(index: 3, stationId: 1004, stationName: "포항시외버스터미널", stationCityCode: 37010, localStationId: "104")

    // 버스 구간 1
    let busNode1 = BusRouteNode(
        start: LocationInfo(name: "포항공대 정문", latitude: 36.0186, longitude: 129.3231),
        end: LocationInfo(name: "죽도시장", latitude: 36.0348, longitude: 129.3435),
        busNo: "107",
        busId: 107,
        stations: [station1, station2],
        travelTime: 15
    )

    // 도보 구간
    let walkNode = WalkRouteNode(
        start: LocationInfo(name: "죽도시장", latitude: 36.0348, longitude: 129.3435),
        end: LocationInfo(name: "포항역", latitude: 36.0716, longitude: 129.3419),
        travelTime: 10
    )

    // 버스 구간 2 (
    let busNode2 = BusRouteNode(
        start: LocationInfo(name: "포항역", latitude: 36.0716, longitude: 129.3419),
        end: LocationInfo(name: "포항시외버스터미널", latitude: 36.0165, longitude: 129.3564),
        busNo: "500",
        busId: 500,
        stations: [station3, station4],
        travelTime: 18
    )

    // 전체 여정 구성
    let journey = Journey(
        totalTime: 43,
        nodes: [
            .bus(busNode1),
            .walk(walkNode),
            .bus(busNode2)
        ]
    )

    // 매니저에 주입
    manager.selectedJourney = journey
    manager.journeyIndex = 0

    // 프리뷰
    return BeforeRideView(manager: manager)
        .environmentObject(NavigationCoordinator())
}
