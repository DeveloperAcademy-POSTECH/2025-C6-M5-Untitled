//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI
import Lottie

struct CongratsView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var showArrivalConfirmation = false
    @State private var isAnimating = false
    @State private var journey: Journey? = JourneyManager.shared.selectedJourney
    
    var body: some View {
        ZStack {
            Color(.primarywhite)
                .ignoresSafeArea()
            
            VStack(spacing: 0.wScaled){
                
                VStack(spacing: 32.wScaled) {
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey {
                        WholeJourney(
                            journey: journey,
                            journeyIndex: journey.nodes.count - 1,
                            isBeforeRide: false
                        )
                        .padding(.horizontal, 32)
                    }
                    
                    LineDivider()
                }
                .frame(height: 144)
                
                ZStack {
                    Color(.background)
                        .ignoresSafeArea()
                    
                    VStack(alignment: .leading) {
                        Spacer()
                        
                        if let destination = JourneyManager.shared.destination {
                            
                            // 2. if/else 분기를 제거하고 MarqueeText 하나만 남겼습니다.
                            MarqueeText(
                                text: destination.name,
                                font: .presemi36Scaled,
                                uiFont: .presemi36Scaled,
                                startDelay: 3.0,
                                alignment: .leading
                            )
                            .foregroundColor(Color.primaryHeavy)
                            .offset(y: showArrivalConfirmation ? 200.wScaled : 0)
                            .animation(.easeOut(duration: 1.0), value: showArrivalConfirmation)
                        }
                        
                        Spacer()
                        
                        if showArrivalConfirmation {
                            ArrivalConfirmation(showArrivalConfirmation: $showArrivalConfirmation)
                            
                            
                            Button {
                                coordinator.popToRoot()
                                showArrivalConfirmation = false
                                ProgressLiveActivityManager.shared.endActivity()
                            } label: {
                                Text("확인")
                                    .foregroundColor(Color.subLight)
                                    .font(.premed32)
                                    .frame(width: 344.wScaled, height: 64)
                                    .background(Color.subPoint)
                                    .cornerRadius(20)
                                
                            }
                            
                        } else {
                            HStack{
                                Spacer()
                                
                                LottieView(animation: .named("check"))
                                    .playing(loopMode: .playOnce)
                                    .animationSpeed(1.0)
                                    .frame(width: 180.wScaled, height: 180.wScaled)
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            showArrivalConfirmation = true
                                        }
                                    }
                                
                                Spacer()
                            }
                            Spacer()
                            
                            Text("도착")
                                .font(.presemi32Scaled)
                                .foregroundColor(.primaryHeavy)
                            Text("했어요!")
                                .font(.prereg32Scaled)
                                .foregroundColor(.primaryHeavy)
                                .padding(.bottom, 80.wScaled)
                        }
                    }
                    .padding(.horizontal,30.wScaled)
                }
            }
        }
    }
}

struct ArrivalConfirmation: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Binding var showArrivalConfirmation: Bool
    
    var body: some View {
        VStack(alignment: .leading){
            Spacer()
            Text("목적지에 도착했어요.")
                .font(.prereg32Scaled)
                .foregroundColor(.primaryHeavy)
            Spacer()
            
        }
        
    }
}
