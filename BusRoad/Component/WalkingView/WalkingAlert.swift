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
        Color.black.opacity(0.6) // 배경 블러 느낌
          .ignoresSafeArea()
        
        Rectangle()
          .frame(width: 300, height: 207)
          .cornerRadius(40)
          .foregroundColor(Color.background)
        VStack(alignment:.leading, spacing: 16){
          Text("혹시 이미 도착하셨나요?")
            .font(.presemi24)
            .foregroundColor(.primary)
            .padding(.leading, 8)
          Text("목적지에 이미 도착하셨다면,\n직접 완료할 수 있어요.")
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
                  .cornerRadius(30)
                  .foregroundColor(Color.primaryLight)
                  .frame(width: 128, height: 48)
                Text("닫기")
                  .foregroundColor(Color.red)
                  .font(.prereg18)
              }
            }
            Button{
              coordinator.advanceJourneyStage()
              isPresented = false
            } label:{
              ZStack{
                Rectangle()
                  .cornerRadius(30)
                  .foregroundColor(Color.subPoint)
                  .frame(width: 128, height: 48)
                Text("완료하기")
                  .foregroundColor(Color.subLight)
                  .font(.prereg18)
              }
            }
          }
        }
        .padding()
      }
    }
  }
}
