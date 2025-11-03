//
//  routeSelectButton.swift
//  BusRoad
//
//  Created by 강진 on 10/12/25.
//

import SwiftUI

struct RouteSelectButton: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel = BusRouteViewModel()
    @Binding var currentIndex: Int
    @State private var currentStage: RouteStage?
    var routes: [Journey]?
    var onSelect: () -> Void
    var retrySearch: () -> Void
    
    var body: some View {
        let isDarkMode = colorScheme == .dark
        
        if viewModel.errorMessage == nil {
            Button {
                if let routes {
                    print("\(isDarkMode)")
                    print("[DEBUG] 버튼 클릭! 현재 index: \(currentIndex)")
                    onSelect()
                    
                    if let selectedJourney = JourneyManager.shared.selectedJourney {
                        if let firstNode = selectedJourney.nodes.first {
                            switch firstNode {
                            case .walk(let walkNode):
                                ProgressLiveActivityManager.shared.startActivity(
                                    totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                                    stage: RouteStage.walkingToBus.rawValue,
                                    destination: walkNode.end.name,
                                    remainingBusStops: 0,
                                    busTravelTime: 0,
                                    isDarkMode: isDarkMode
                                )
                            case .bus(let busNode):
                                let destinationName = selectedJourney.busSegments.first?.end.name ?? "목적지"
                                ProgressLiveActivityManager.shared.startActivity(
                                    totalDistance: 0,
                                    stage: RouteStage.waitingForBus.rawValue,
                                    destination: destinationName,
                                    remainingBusStops: busNode.stations.count,
                                    busTravelTime: busNode.travelTime,
                                    isDarkMode: isDarkMode
                                )
                            }
                        }
                    }
                    
                } else {
                    print("[DEBUG] routes가 존재하지 않습니다.")
                }
            } label: {
                Text("시작하기")
                    .foregroundColor(Color.subLight)
                    .font(.premed32)
                    .frame(width: 305.wScaled, height: 64)
                    .background(Color.subPoint)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        } else if viewModel.errorMessage == "지원하지 않는 교통수단이 포함되어 있습니다." {
            Button {
                retrySearch()
            } label: {
                Text("다시 검색하기")
                    .foregroundColor(Color.subLight)
                    .font(.premed32)
                    .frame(width: 305.wScaled, height: 64)
                    .background(Color.subPoint)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 65)
        } else if viewModel.errorMessage == "출발지와 목적지가 너무 가깝습니다." {
            Button {
                viewModel.createWalkingJourneyIfNeeded()
                onSelect()
                
                if let selectedJourney = JourneyManager.shared.selectedJourney {
                    if case let .walk(node) = selectedJourney.nodes.first{
                        ProgressLiveActivityManager.shared.startActivity(
                            totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                            stage: RouteStage.walkingToDestination.rawValue,
                            destination: node.end.name,
                            remainingBusStops: 0,
                            busTravelTime: 0,
                            isDarkMode: isDarkMode
                        )
                    }
                }
                
            } label: {
                Text("도보 이동하기")
                    .foregroundColor(Color.subLight)
                    .font(.premed32)
                    .frame(width: 305.wScaled, height: 64)
                    .background(Color.subPoint)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        } else if viewModel.errorMessage == "출발지와 도착지가 같습니다." {
            Button {
                retrySearch()
            } label: {
                Text("처음으로")
                    .foregroundColor(Color.subLight)
                    .font(.premed32)
                    .frame(width: 305.wScaled, height: 64)
                    .background(Color.subPoint)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        } else {
            Button {
                if let origin = viewModel.origin, let destination = viewModel.destination {
                    viewModel.validateAndFetchRoute(origin: origin, destination: destination)
                } else {
                    retrySearch()
                }
            } label: {
                Text("새로고침 하기")
                    .foregroundColor(Color.subLight)
                    .font(.premed32)
                    .frame(width: 305.wScaled, height: 64)
                    .background(Color.subPoint)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
    }
}
