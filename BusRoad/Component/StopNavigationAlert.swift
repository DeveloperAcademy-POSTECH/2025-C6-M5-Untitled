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
          .ignoresSafeArea()
        
        Rectangle()
          .frame(width: 300, height: 199)
          .cornerRadius(35)
          .foregroundColor(Color.background)
        VStack(alignment:.center, spacing: 16){
          Text("경로 안내를 종료할까요?")
            .font(.presemi24)
            .foregroundColor(.primary)
            .padding(.leading, 8)
          Text("페이지를 종료하면 경로 안내가\n종료돼요.")
            .font(.prereg20)
            .foregroundColor(.primary)
            .lineSpacing(5)
            .multilineTextAlignment(.leading)
            .padding(.leading, 8)
          HStack(spacing: 16){
            Button{
              isPresented = false
            } label:{
              ZStack{
                Rectangle()
                  .cornerRadius(100)
                  .foregroundColor(Color.primaryLight)
                  .frame(width: 128, height: 48)
                Text("닫기")
                  .foregroundColor(Color.greyStrong)
                  .font(.premed20)
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
                  .frame(width: 128, height: 48)
                Text("종료하기")
                  .foregroundColor(Color.subLight)
                  .font(.premed20)
              }
            }
          }
        }
        .padding()
      }
      .background(.clear)
    }
  }
}
