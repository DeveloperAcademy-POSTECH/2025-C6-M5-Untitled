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
    @State private var journey: Journey? = JourneyManager.shared.selectedJourney
    
    var body: some View {
        ZStack {
            Color(.primarywhite)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 0){
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey {
                        WholeJourney(
                            journey: journey,
                            journeyIndex: journey.nodes.count - 1,
                            isBeforeRide: false
                        )
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                    }
                }
                .frame(height: 128)
                
                LineDivider()
                
                ZStack {
                    Color(.background)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        if let destination = JourneyManager.shared.destination {
                            VStack(spacing: 8) {
                                Text("목적지까지 걷기")
                                    .font(.prereg20)
                                    .foregroundColor(.primaryHeavy)
                                
                                MarqueeText(
                                    text: destination.name,
                                    font: .presemi36Scaled,
                                    uiFont: .presemi36Scaled,
                                    startDelay: 1.0,
                                    alignment: .center
                                )
                                .foregroundColor(.primaryHeavy)
                            }
                            .padding(.top, 44.wScaled)
                            .padding(.horizontal, 32.wScaled)
                            Spacer()
                        }
                        
                            
                            VStack(spacing: 60) {
                                
                                HStack {
                                    Spacer()
                                    LottieView(animation: .named("check"))
                                        .playing(loopMode: .playOnce)
                                        .animationSpeed(1.0)
                                        .frame(width: 180, height: 180)
                                    Spacer()
                                }
                                
                                Text("도착했어요!")
                                    .font(.presemi32Scaled)
                                    .foregroundColor(.primaryHeavy)
                            }
                            .padding(.horizontal, 32.wScaled)
                            
                            Spacer()
                            
                            // 확인 버튼
                            Button {
                                coordinator.popToRoot()
                                ProgressLiveActivityManager.shared.endActivity()
                            } label: {
                                Text("확인")
                                    .foregroundColor(.white)
                                    .font(.premed32Scaled)
                                    .frame(width: 344.wScaled, height: 64.wScaled)
                                    .background(Color.subPoint)
                                    .cornerRadius(20)
                            }
                        }
                }
            }
        }
    }
}
