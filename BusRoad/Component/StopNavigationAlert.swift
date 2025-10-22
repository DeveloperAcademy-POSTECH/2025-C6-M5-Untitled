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
        Color.black
              .opacity(0.5)
          .ignoresSafeArea()
        VStack(alignment:.center){
          Text("경로 안내를 종료할까요?")
            .font(.presemi24Scaled)
            .foregroundColor(.primary)
            .padding(.top, 18.wScaled)
            .padding(.bottom, 10.wScaled)
          Text("페이지를 나가면\n경로 안내가 종료돼요.")
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
              onXMark()
              isPresented = false
            } label:{
              ZStack{
                Rectangle()
                  .cornerRadius(100)
                  .foregroundColor(Color.cancelbutton)
                  .frame(width: 139.wScaled, height: 48.wScaled)
                Text("종료하기")
                  .foregroundColor(Color.subLight)
                  .font(.premed20Scaled)
              }
            }
          }
        }
        .padding(.vertical, 15.wScaled)
        .frame(width: 320.wScaled)
        .background(
            RoundedRectangle(cornerRadius: 35)
            .fill(.regularMaterial)
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
