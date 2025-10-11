//
//  RouteErrorCard.swift
//  BusRoad
//
//  Created by 강진 on 10/12/25.
//

import SwiftUI

struct RouteErrorCard: View {
    var body: some View {
      ZStack{
        Rectangle()
            .foregroundColor(Color.primaryNormal)
            .frame(width: 305, height: 423)
            .cornerRadius(20)
        Text("앗, 문제가 발생했어요😵\n경로를 다시 검색해주세요.")
          .font(.presemi24)
          .foregroundColor(Color.subLight)
      }
    }
}

#Preview {
    RouteErrorCard()
}
