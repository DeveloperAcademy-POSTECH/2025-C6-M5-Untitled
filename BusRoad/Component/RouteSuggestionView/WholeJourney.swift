//
//  WholeJourney.swift
//  C6test
//
//  Created by 강진 on 9/27/25.
//

import SwiftUI

// TODO: RouteSuggestion의 wholeJourney -> RouteSummary를 추가해서 대체함. 이 컴포넌트는 탑승 전/중 뷰 상단에 들어가는 컴포넌트로 수정 필요
struct WholeJourney: View {
  var journey: Journey
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

