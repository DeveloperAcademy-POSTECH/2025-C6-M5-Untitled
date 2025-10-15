//
//  BoardingLocation.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct BoardingLocation: View {
  var route: BusRouteNode
  var body: some View {
    
    VStack(alignment:.leading){
        Text("탑승 정류장")
          .font(.prereg20)
          .foregroundColor(Color.subLight)
        Text("\(route.start.name)")
          .font(.presemi32)
          .foregroundColor(Color.subLight)
          .padding([.top, .bottom], 5)
      HStack{
        Text("\(route.busNo)번")
            .font(.presemi24)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Rectangle()
                    .cornerRadius(15)
                    .foregroundColor(Color.subNormal)
            )
        // TODO: 실시간 버스 도착 예정 시간으로 수정해야 함!! (실시간 API 활용 필요)
        Text("3분 후 도착")
          .font(.prereg16)
          .foregroundColor(Color.subLight)
      }
    }
  }
}
