//
//  OriginTextFieldView.swift
//  BusRoad
//
//  Created by 강진 on 9/28/25.
//

import SwiftUI

struct OriginTextField : View {
  @Binding var location: LocationInfo?
  
  var onRefreshTapped: () -> Void
  
  var body: some View {
    ZStack {
      ZStack {
        RoundedRectangle(cornerSize: .init(width: 10, height: 10))
          .stroke(Color.black)
          .frame(height:50)
          .foregroundColor(.clear)
        HStack{
          Text("출발지")
            .padding(.leading, 10)
          Divider()
          TextField(
            "출발지를 입력하세요",
            text: Binding(
              get: { self.location?.name ?? "" },
              set: { newName in
                if self.location == nil {
                  self.location = LocationInfo(name: newName, longitude: 0, latitude: 0)
                } else {
                  self.location?.name = newName
                }
              }
            )
          )
          Spacer()
          Button(action: {
            self.onRefreshTapped()
          }, label: {
            Image(systemName:"arrow.clockwise")
              .padding(.trailing, 10)
          })
        }
        .frame(height: 30)
      }
    }
  }
}
