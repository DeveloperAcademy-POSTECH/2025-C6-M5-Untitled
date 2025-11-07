//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import MapKit
import SwiftUI

struct WalkingView: View {
    @ObservedObject var viewModel = WalkingViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    var body: some View {
        ZStack {
            Color(.primarywhite)
                .ignoresSafeArea()
            
            VStack(spacing: 0){
                
                VStack(spacing: 0) {
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                        WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: false)
                            .padding(32)
                    }
                }
                .frame(height: 144)
                .onChange(of: viewModel.arrived) { _, newValue in
                    if newValue,
                       let journey = viewModel.journey,
                       let index = viewModel.journeyIndex,
                       index == journey.nodes.count - 1 {
                        coordinator.advanceJourneyStage()
                    }
                }
              
                LineDivider()
                
                ZStack {
                    Color(.background)
                        .ignoresSafeArea()
                    
                    VStack {
                        if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                            if viewModel.arrived {
                                AtArrival(journey: journey, index: index, viewModel: viewModel)
                            } else {
                                ToDestination(vm:viewModel, journey: journey, index: index)
                                
                                Spacer()
                                
                                
                                Button {
                                    viewModel.showAlert = true
                                } label: {
                                    if index == journey.nodes.count - 1 {
                                        Text("이미 목적지에 도착하셨나요?")
                                            .font(.premed14Scaled)
                                            .foregroundColor(.primaryHeavy)
                                            .underline()
                                    } else {
                                        Text("이미 정류장에 도착하셨나요?")
                                            .font(.premed14Scaled)
                                            .foregroundColor(.primaryHeavy)
                                            .underline()
                                    }
                                }
                                
                            }
                        }
                    }
                }
            }
            
            // 맵뷰 버튼
            VStack {
                Spacer()    // 높이 144(고정) + 120.wScaled(변동)
                    .frame(height: 144 + 120.wScaled)
                    
                HStack {
                    Spacer()
                    Button {
                        viewModel.showDevSheet = true
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.system(size: 20.wScaled, weight: .bold))
                            .foregroundColor(.subLight)
                            .padding(.vertical, 12.wScaled)
                            .padding(.horizontal, 18.wScaled)
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 10,
                                    bottomLeadingRadius: 10
                                )
                                .fill(Color.subStrong)
                            )
                    }
                }
                Spacer()
            }
            .overlay {
                if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                    WalkingAlert(isPresented: $viewModel.showAlert, viewModel: viewModel, journey: journey, index: index)
                }
            }
        }
        // 맵뷰 바텀 시트
        .sheet(isPresented: $viewModel.showDevSheet) {
            DevRouteMapView(
                tmapCoordinates: viewModel.tmapCoordinates,
                userLocation: viewModel.loc.location,
                destination: viewModel.pendingDestination
            )
            .presentationDetents([.fraction(0.4), .large])
            .presentationDragIndicator(.visible)
        }
    }
}
