//
//  StopNavigationAlert.swift
//  BusRoad
//
//  Created by 강진 on 10/21/25.
//

import SwiftUI

struct StopNavigationAlert: View {
  @EnvironmentObject var coordinator: NavigationCoordinator
  @Binding var isPresented: Bool
  var onXMark: () -> Void
  
  var body: some View {
    if isPresented {
      ZStack {
        Color.primaryblack
              .opacity(0.5)
          .ignoresSafeArea()
        VStack(alignment:.center){
          Text("경로 안내를 종료할까요?")
            .font(.presemi24Scaled)
            .foregroundColor(.primaryblack)
            .padding(.top, 20.wScaled)
            .padding(.bottom, 10.wScaled)
            
          Text("페이지를 나가면 경로 안내가\n종료돼요.")
            .font(.prereg20Scaled)
            .foregroundColor(.primaryblack)
           .multilineTextAlignment(.center)
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
                Text("취소")
                  .foregroundColor(Color.primaryblack)
                  .font(.premed20Scaled)
              }
            }
            Button{
              onXMark()
              isPresented = false
            } label:{
              ZStack{
                Rectangle()
                  .cornerRadius(100)
                  .foregroundColor(Color.cancelbutton)
                  .frame(width: 139.wScaled, height: 48.wScaled)
                Text("종료하기")
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
            .fill(.alertbackground)
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
