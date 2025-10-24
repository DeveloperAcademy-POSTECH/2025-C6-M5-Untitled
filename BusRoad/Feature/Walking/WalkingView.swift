//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI
import MapKit

struct WalkingView: View {
    @ObservedObject var vm = WalkingViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var showAlert = false
    @State private var showDevSheet = false  // [CHECK] 개발자용 맵 시트 상태
    
    var journey: Journey?
    var index: Int?
    
    init(manager: JourneyManager = .shared) {
        if let journey = manager.selectedJourney, let index = manager.journeyIndex {
            self.journey = journey
            self.index = index
        }
    }
    
    var body: some View {
        ZStack {
            Color(.primarywhite)
                .ignoresSafeArea()
            
            VStack(spacing: 0){
                
                VStack(spacing: 0) {
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey, let index {
                        WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: false)
                            .padding(32)
                    }
                }
                .frame(height: 144)
                
                LineDivider()
                
                ZStack {
                    Color(.background)
                        .ignoresSafeArea()
                    
                    VStack {
                        if let journey, let index {
                            if vm.arrived {
                                AtArrival(journey: journey, index: index)
                            } else {
                                ToDestination(vm:vm, journey: journey, index: index)
                                
                                Spacer()
                                
                                
                                Button {
                                    showAlert = true
                                } label: {
                                    Text("이미 목적지에 도착하셨나요?")
                                        .font(.premed12Scaled)
                                        .foregroundColor(.primaryHeavy)
                                        .underline()
                                }
                                
                            }
                        }
                    }
                }
            }
            .overlay(
                WalkingAlert(isPresented: $showAlert)
            )
            
            // [CHECK] 개발자용 뷰 버튼
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showDevSheet = true
                    } label: {
                        Image(systemName: "wrench.adjustable")
                            .padding(8)
                    }
                }
                Spacer()
            }
        }
        // [CHECK] 개발자용 바텀 시트
        .sheet(isPresented: $showDevSheet) {
            DevRouteMapView(route: vm.route)
                .presentationDetents([.fraction(0.4), .large])  // 반만/전체 표시
                .presentationDragIndicator(.visible)    // 위에 바 표시
        }
    }
}
