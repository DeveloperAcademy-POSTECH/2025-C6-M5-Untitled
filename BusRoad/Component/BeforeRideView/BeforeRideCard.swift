//
//  Card.swift
//  C6test
//
//  Created by 강진 on 10/1/25.
//

import SwiftUI
import Lottie


struct BeforeRideCard: View {
    @ObservedObject var viewModel = BeforeRideViewModel()
    var waitingStopName: String
    var waitingBusNo: [String]
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(viewModel.isArrivingSoon ? .primaryStrong : .primarywhite)
                .cornerRadius(20)
                .shadow(
                    color: viewModel.isArrivingSoon ? .clear : .black.opacity(0.25),
                    radius: viewModel.isArrivingSoon ? 0 : 2,
                    x: 0,
                    y: 0
                )
            
            VStack(spacing: 30.wScaled) {
                VStack(spacing: 28.wScaled) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8.wScaled) {
                            MarqueeText(
                                text: waitingStopName,
                                font: .presemi32Scaled,
                                uiFont: .presemi32Scaled,
                                startDelay: 1.0,
                                alignment: .leading
                            )
                            .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                            
                            Text("정류장에서 타야 해요.")
                                .font(.prereg24Scaled)
                                .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                        }
                        Spacer()
                    }
                    
                    if let info = viewModel.nearestBusInfo {
                        HStack {
                            Text(info.busNo)
                                .font(.presemi32Scaled)
                                .foregroundStyle(viewModel.isArrivingSoon ? .primaryHeavy : .subLight)
                                .padding(.horizontal, 8.wScaled)
                                .padding(.vertical, 4.wScaled)
                                .background(
                                    Rectangle()
                                        .foregroundStyle(viewModel.isArrivingSoon ? .subNormal : .primaryHeavy)
                                        .cornerRadius(15)
                                )
                            
                            Spacer()
                                .frame(width: 8.wScaled)
                            
                            Text(info.arrivalText)
                                .font(.premed20Scaled)
                                .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                            
                            Spacer()
                        }
                    } else {
                        if viewModel.didFetchOnce {
                            HStack {
                                Text(waitingBusNo[0])
                                    .font(.presemi32Scaled)
                                    .foregroundStyle(.subLight)
                                    .padding(.horizontal, 8.wScaled)
                                    .padding(.vertical, 4.wScaled)
                                    .background(
                                        Rectangle()
                                            .foregroundColor(.primaryHeavy)
                                            .cornerRadius(15)
                                    )
                                
                                Spacer()
                                    .frame(width: 8.wScaled)
                                
                                Text("도착 정보 없음")
                                    .font(.premed20Scaled)
                                    .foregroundStyle(viewModel.isArrivingSoon ? .subLight : .primaryHeavy)
                                
                                Spacer()
                            }
                        } else {
                            HStack {
                                Text(waitingBusNo[0])
                                    .font(.presemi32Scaled)
                                    .foregroundStyle(.subLight)
                                    .padding(.horizontal, 8.wScaled)
                                    .padding(.vertical, 4.wScaled)
                                    .background(
                                        Rectangle()
                                            .foregroundColor(.primaryHeavy)
                                            .cornerRadius(15)
                                    )
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                LottieView(animation: .named(viewModel.isArrivingSoon ? "BeforeBoarding" : "BeforeRiding"))
                    .playing(loopMode: .loop)  // 반복 재생
                    .animationSpeed(1.0)  // 재생 속도
                    .frame(width: 200.wScaled, height: 200.wScaled)
                    .padding(.leading, viewModel.isArrivingSoon ? 25.wScaled : 0)
                    .padding(.top, viewModel.isArrivingSoon ? 20.wScaled : 0)
                
                
            }
            .padding(.horizontal, 40.wScaled)
        }
    }
}
