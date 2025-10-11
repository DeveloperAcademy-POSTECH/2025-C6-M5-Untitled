//
//  OriginTextField.swift
//  BusRoad
//
//  Created by 강진 on 9/28/25.
//

import SwiftUI

struct OriginTextField : View {
  @EnvironmentObject var coordinator: NavigationCoordinator
  @Binding var location: LocationInfo?
  
  var onRefreshTapped: () -> Void
  
  var body: some View {
    ZStack {
      ZStack {
        RoundedRectangle(cornerSize: .init(width: 25, height: 25))
          .stroke(Color.subStrong)
          .frame(width: 350, height:50)
          .foregroundColor(.clear)
        HStack(spacing: 10){
          Text("출발지")
            .foregroundColor(Color.greyNormal)
            .font(.prereg20)
            .padding(.leading, 30)

          Divider()
            .background(Color.greyDisable)

          Button(action: {
            coordinator.push(.mainSearch) // TODO: 임시 내비게이션
          }) {
            Text(location?.name ?? "출발지를 입력하세요")
              .font(.premed20)
              .foregroundColor(Color.greyNormal)
          }
          Spacer()
          Button(action: {
            self.onRefreshTapped()
          }, label: {
            Image(systemName:"arrow.clockwise")
              .resizable()
              .foregroundColor(Color.greyNormal)
              .frame(width:18, height: 18)
              .padding(.trailing, 10)
          })
          .padding(.trailing, 20)
        }
        .frame(height: 30)
      }
    }
  }
}
