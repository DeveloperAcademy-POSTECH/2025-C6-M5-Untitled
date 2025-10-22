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
  
  var body: some View {
    if isPresented {
      ZStack {
        Color.black
              .opacity(0.5)
          .ignoresSafeArea()
        
        VStack(alignment:.center){
          Text("목적지에 도착하셨나요?")
            .font(.presemi24Scaled)
            .foregroundColor(.primary)
            .padding(.top, 18.wScaled)
            .padding(.bottom, 10.wScaled)
          Text("목적지에 이미 도착하셨다면,\n직접 경로를 완료할 수 있어요.")
            .font(.prereg20Scaled)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 24.wScaled)
          HStack(spacing: 10.wScaled){
            Button{
              isPresented = false
            } label:{
              ZStack{
                Rectangle()
                  .cornerRadius(100)
                  .foregroundColor(Color.greybutton.opacity(0.2))
                  .frame(width: 139.wScaled, height: 48.wScaled)
                Text("닫기")
                  .foregroundColor(Color.black)
                  .font(.premed20Scaled)
              }
            }
            Button{
              coordinator.advanceJourneyStage()
              isPresented = false
            } label:{
              ZStack{
                Rectangle()
                  .cornerRadius(100)
                  .foregroundColor(Color.subPoint)
                  .frame(width: 139.wScaled, height: 48.wScaled)
                Text("완료하기")
                  .foregroundColor(Color.primarywhite)
                  .font(.premed20Scaled)
              }
            }
          }
        }
        .padding(.vertical, 15.wScaled)
        .frame(width: 320.wScaled)
          
        .background(
            RoundedRectangle(cornerRadius: 35)
            .fill(.regularMaterial) // 내부 색상
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
