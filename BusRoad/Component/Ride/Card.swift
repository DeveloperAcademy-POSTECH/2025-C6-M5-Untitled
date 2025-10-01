//
//  Card.swift
//  C6test
//
//  Created by 강진 on 10/1/25.
//

import SwiftUI


struct Card: View {
  var isActive: Bool
  var busStop: String
  var instruction: String
  
  var body: some View {
    ZStack {
      Rectangle()
        .foregroundColor(isActive ? .gray : .green)
        .frame(width: UIScreen.main.bounds.width * 0.85, height: UIScreen.main.bounds.height * 0.5)
        .cornerRadius(20)
      VStack(alignment:.leading){
        Text(busStop)
          .font(.title)
          .padding(.top, 70)
        Text(instruction)
          .font(.title2)
          .padding(.top, 3)
        Spacer()
      }
      .frame(width: UIScreen.main.bounds.width * 0.7, height: UIScreen.main.bounds.height * 0.5, alignment: .leading)
    }
  }
}
