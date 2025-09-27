//
//  ETAView.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

struct ETAView: View {
  var route: BusRoute
  var isFirstCard: Bool
  
  var body: some View {
    HStack{
      VStack(alignment:.leading){
        Text("\(route.totalTime) 분")
          .font(.largeTitle)
          .foregroundColor(.white)
        Text("\(route.estimatedArrivalTime) 도착 예정")
      }
     if isFirstCard {
      ZStack{
       RoundedRectangle(cornerRadius: 10)
        .foregroundColor(.black)
        .frame(width: 80, height: 35)
       Text("추천")
        .foregroundColor(.white)
      }
      .padding(.leading, 70)
     }
    }
  }
}
