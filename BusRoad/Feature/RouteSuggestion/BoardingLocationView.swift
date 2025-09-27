//
//  BoardingLocationView.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct BoardingLocationView: View {
  var route: BusRoute
  var body: some View {
    VStack(alignment:.leading){
      Text("\(route.boardingLocation)에서 탑승")
        .font(.title2)
      HStack{
          Text(route.busNumbers.first ?? "")
            .font(.title2)
        //실시간 버스 도착 예정 시간으로 수정해야 함!! (실시간 API 활용 필요)
        Text("3분 뒤 도착")
      }
    }
  }
}
