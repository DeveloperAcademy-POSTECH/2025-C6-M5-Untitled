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
          .ignoresSafeArea()
        
        Rectangle()
          .frame(width: 300, height: 199)
          .cornerRadius(35)
          .foregroundColor(Color.background)
        VStack(alignment:.center, spacing: 16){
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
                  .cornerRadius(100)
                  .foregroundColor(Color.primaryLight)
                  .frame(width: 128, height: 48)
                Text("닫기")
                  .foregroundColor(Color.greyStrong)
                  .font(.premed20)
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
                  .frame(width: 128, height: 48)
                Text("완료하기")
                  .foregroundColor(Color.primarywhite)
                  .font(.premed20)
              }
            }
          }
        }
        .padding()
      }
    }
  }
}
