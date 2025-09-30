//
//  WholeJourneyView.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

//여기는 아직 대대적 작업이 필요함,,, 루트 가져와서 시각화 어떻게 할지 고민해봐야 함...
struct WholeJourneyView: View {
  var route: BusRoute
  var body: some View {
    ZStack{
      Rectangle()
        .frame(width: 270, height: 5)
      HStack{
        ZStack{
          Circle()
            .frame(width: 28, height:28)
            .foregroundColor(.green)
          Image(systemName: "bus.fill")
            .frame(width:12, height:12)
            .foregroundColor(.white)
        }
        Spacer()
        ZStack{
          Circle()
            .frame(width: 28, height:28)
            .foregroundColor(.black)
          Image(systemName: "figure.walk")
            .frame(width:12, height:12)
            .foregroundColor(.white)
        }
      }
      .frame(width: 280)
    }
  }
}

