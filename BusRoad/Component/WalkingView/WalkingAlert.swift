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
        Color.primaryblack
              .opacity(0.5)
          .ignoresSafeArea()
        
        VStack(alignment:.center){
          Text("목적지에 도착하셨나요?")
            .font(.presemi24Scaled)
            .foregroundColor(.primaryblack)
            .padding(.top, 20.wScaled)
            .padding(.bottom, 36.wScaled)
            
          HStack(spacing: 9.wScaled){
            Button{
              isPresented = false
            } label:{
              ZStack{
                Rectangle()
                  .cornerRadius(100)
                  .foregroundColor(Color.greybutton)
                  .frame(width: 139.wScaled, height: 48.wScaled)
                Text("아니요")
                  .foregroundColor(Color.primaryblack)
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
                Text("네")
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
                .fill(Color.alertbackground) // 내부 색상
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
