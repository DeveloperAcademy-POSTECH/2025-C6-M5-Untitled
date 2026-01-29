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
    @ObservedObject var viewModel: WalkingViewModel
    
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
                        Text(NSLocalizedString("alert_arrival_destination", comment: "이미 목적지에 도착하셨나요?"))
                            .font(.presemi24Scaled)
                            .foregroundColor(.primaryblack)
                            .padding(.top, 20.wScaled)
                            .padding(.bottom, 36.wScaled)
                    } else {
                        Text(NSLocalizedString("alert_arrival_busStop", comment: "이미 정류장에 도착하셨나요?"))
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
                                Text("아니오")
                                    .foregroundColor(Color.primaryblack)
                                    .font(.premed20Scaled)
                            }
                        }
                        Button{
                            viewModel.manuallyArrived = true
                            viewModel.arrived = true
                            isPresented = false
                        } label:{
                            ZStack{
                                Rectangle()
                                    .cornerRadius(100)
                                    .foregroundColor(Color.subPoint)
                                    .frame(width: 139.wScaled, height: 48.wScaled)
                                Text(NSLocalizedString("walking_alert_arrived", comment: "도착"))
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
