//
//  RouteCardView.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCard: View {
    var route: BusRoute
    var isFirstCard: Bool
  
    var body: some View {
      ZStack{
        Rectangle()
          .foregroundColor(.gray)
          .frame(width: 317, height: 400)
          .cornerRadius(20)
        VStack(alignment:.leading){
          Spacer()
          ETA(route: route, isFirstCard: isFirstCard)
          Spacer()
          BoardingLocation(route: route)
          Spacer()
          WholeJourney(route: route)
          Spacer()
        }
        .frame(width: 317, height: 400)
        .padding(.leading, 5)
      }
    }
}
