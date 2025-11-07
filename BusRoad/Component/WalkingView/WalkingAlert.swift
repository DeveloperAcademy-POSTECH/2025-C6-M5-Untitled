//
//  Alert.swift
//  BusRoad
//
//  Created by 강진 on 10/21/25.
//

import SwiftUI

struct WalkingAlert: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Binding var isPresented: Bool
    
    let journey: Journey
    let index: Int
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.primaryblack
                    .opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(alignment:.center){
                    if index == journey.nodes.count - 1 {
                        Text("이미 목적지에 도착하셨나요?")
                            .font(.presemi24Scaled)
                            .foregroundColor(.primaryblack)
                            .padding(.top, 20.wScaled)
                            .padding(.bottom, 36.wScaled)
                    } else {
                        Text("이미 정류장에 도착하셨나요?")
                            .font(.presemi24Scaled)
                            .foregroundColor(.primaryblack)
                            .padding(.top, 20.wScaled)
                            .padding(.bottom, 36.wScaled)
                    }
                    HStack(spacing: 9.wScaled){
                        Button{
                            isPresented = false
                        } label:{
                            ZStack{
                                Rectangle()
                                    .cornerRadius(100)
                                    .foregroundColor(Color.greybutton)
                                    .frame(width: 139.wScaled, height: 48.wScaled)
                                Text("닫기")
                                    .foregroundColor(Color.primaryblack)
                                    .font(.premed20Scaled)
                            }
                        }
                        Button{
                            coordinator.advanceJourneyStage()
                            
                            if index + 1 < journey.nodes.count {
                                    if case let .bus(busnode) = journey.nodes[index + 1] {
                                        print("다음 노드가 버스입니다:", busnode.busNo)
                                        ProgressLiveActivityManager.shared.updateStage(
                                            nextStage: RouteStage.waitingForBus.rawValue,
                                            nextDestination: busnode.start.name,
                                            totalDistance: 0,
                                            remainingBusStops: busnode.stations.count,
                                            busTravelTime: busnode.travelTime
                                        )
                                    } else {
                                        print("다음 노드는 버스가 아님:", journey.nodes[index + 1])
                                    }
                                } else {
                                    print("마지막 노드이므로 updateStage 호출 안함")
                                }

                            isPresented = false
                        } label:{
                            ZStack{
                                Rectangle()
                                    .cornerRadius(100)
                                    .foregroundColor(Color.subPoint)
                                    .frame(width: 139.wScaled, height: 48.wScaled)
                                Text("도착")
                                    .foregroundColor(Color.primarywhite)
                                    .font(.premed20Scaled)
                            }
                        }
                    }
                }
                .padding(.vertical, 20.wScaled)
                .frame(width: 320.wScaled)
                
                .background(
                    RoundedRectangle(cornerRadius: 35)
                        .fill(.alertbackground) // 내부 색상
                        .overlay(
                            RoundedRectangle(cornerRadius: 35)
                                .stroke(Color.primarywhite, lineWidth: 0.5)
                        )
                )
            }
            .background(.clear)
        }
    }
}
