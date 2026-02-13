//
//  routeSelectButton.swift
//  BusRoad
//
//  Created by 강진 on 10/12/25.
//

import SwiftUI

struct RouteSelectButton: View {
    @ObservedObject var viewModel = BusRouteViewModel()
    @Binding var currentIndex: Int
    @State private var currentStage: RouteStage?
    var routes: [Journey]?
    var onSelect: () -> Void
    var retrySearch: () -> Void

    private let languageCode = Locale.current.language.languageCode?.identifier
    
    var body: some View {
        if viewModel.errorMessage == nil {
            Button {
                if let routes {
                    print("[DEBUG] 버튼 클릭! 현재 index: \(currentIndex)")
                    onSelect()
                    
                    if let selectedJourney = JourneyManager.shared.selectedJourney {
                        if let firstNode = selectedJourney.nodes.first {
                            switch firstNode {
                            case .walk(let walkNode):
                                // 수정: walkNode.end.name은 승차 정류장 이름
                                let destination = self.languageCode == "ko" ? walkNode.end.name : walkNode.end.englishName ?? walkNode.end.name
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    ProgressLiveActivityManager.shared.startActivity(
                                        totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                                        stage: RouteStage.walkingToBus.rawValue,
                                        destination: destination,  // 승차 정류장 이름
                                        remainingBusStops: 0,
                                        timeTillBusArrival: 0
                                    )
                                }
                                print("[DEBUG] Live Activity 시작 - walkingToBus, destination: \(destination)")
                            case .bus(let busNode):
                                let busSegmentEnd = selectedJourney.busSegments.first?.end
                                let destinationName = self.languageCode == "ko" ? (busSegmentEnd?.name ?? "목적지") : (busSegmentEnd?.englishName ?? busSegmentEnd?.name ?? "Destination")
                                ProgressLiveActivityManager.shared.startActivity(
                                    totalDistance: 0,
                                    stage: RouteStage.waitingForBus.rawValue,
                                    destination: destinationName,
                                    remainingBusStops: busNode.stations.count,
                                    timeTillBusArrival: ArrivalInfoManager.shared.lastNearestArrTime ?? 0
                                )
                                print("[DEBUG] Live Activity 시작 - waitingForBus, destination: \(destinationName)")
                            }
                        }
                    }
                    
                } else {
                    print("[DEBUG] routes가 존재하지 않습니다.")
                }
            } label: {
                Text("안내 시작")
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
                Text("다시 검색")
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
                        let destination = languageCode == "ko" ? node.end.name : node.end.englishName ?? node.end.name
                        ProgressLiveActivityManager.shared.startActivity(
                            totalDistance: Double(WalkingViewModel().tmapTotalDistance),
                            stage: RouteStage.walkingToDestination.rawValue,
                            destination: destination,
                            remainingBusStops: 0,
                            timeTillBusArrival: 0
                        )
                    }
                }
                
            } label: {
                Text("안내 시작")
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
                Text("다시 검색")
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
                    .frame(width: 305.wScaled, height: 64.wScaled)
                    .background(Color.subPoint)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
    }
}
