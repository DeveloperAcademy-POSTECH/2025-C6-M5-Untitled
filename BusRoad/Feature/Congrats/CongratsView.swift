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
    @State private var showConfetti: Bool = false
    
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
                                        .onAppear {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                withAnimation(.easeOut(duration: 0.3)) {
                                                    showConfetti = true
                                                }
                                            }
                                        }
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
                    
                    if showConfetti {
                        GeometryReader { proxy in
                            let screenWidth = proxy.size.width
                            let screenHeight = proxy.size.height
                            
                            let animationWidth: CGFloat = 1400
                            let animationHeight: CGFloat = 1080
                            
                            // 세로 기준으로만 스케일 (아래까지 꽉 차게)
                            let scale = screenHeight / animationHeight
                            
                            LottieView(animation: .named("confetti"))
                                .playing(loopMode: .playOnce)
                                .animationSpeed(0.5)
                                .frame(width: animationWidth, height: animationHeight)
                                .scaleEffect(scale)
                                .position(x: screenWidth / 2, y: screenHeight / 2)
                                .clipped()
                                .allowsHitTesting(false)

                        }
                        .ignoresSafeArea()
                    }
                }
            }
        }
    }
}

#Preview {
    // Seed shared managers for a meaningful preview
    let jm = JourneyManager.shared
    // Sample locations
    let origin = LocationInfo(name: "현위치", latitude: 37.5665, longitude: 126.9780)
    let mid = LocationInfo(name: "버스 환승 지점", latitude: 37.5651, longitude: 126.9895)
    let dest = LocationInfo(name: "포스텍 정문", latitude: 36.0133, longitude: 129.3235)

    // Build a simple journey: walk -> bus -> walk
    let walk1 = WalkRouteNode(start: origin, end: mid, travelTime: 8).asRouteNode
    let busStations = [
        BusStation(index: 0, stationId: 1001, stationName: "시청", stationCityCode: 11, localStationId: "loc-1001", nodeId: "ars-1001", latitude: 37.5665, longitude: 126.9780),
        BusStation(index: 1, stationId: 1002, stationName: "을지로입구", stationCityCode: 11, localStationId: "loc-1002", nodeId: "ars-1002", latitude: 37.5663, longitude: 126.9820)
    ]
    let busNode = BusRouteNode(
        start: mid,
        end: dest,
        busNo: ["100번"],
        busId: [100],
        stations: busStations,
        travelTime: 30
    ).asRouteNode
    let walk2 = WalkRouteNode(start: dest, end: dest, travelTime: 1).asRouteNode

    let sampleJourney = Journey(totalTime: 39, nodes: [walk1, busNode, walk2])

    // Set JourneyManager shared state
    jm.setOrigin(origin)
    jm.setDestination(dest)
    jm.selectedJourney = sampleJourney
    jm.journeyIndex = sampleJourney.nodes.count - 1 // last node for Congrats

    // Coordinator environment object
    let coordinator = NavigationCoordinator()

    return CongratsView()
        .environmentObject(coordinator)
}
