//
//  Button.swift
//  C6test
//
//  Created by 강진 on 10/1/25.
//

import SwiftUI

struct CustomButton: View {
  var isDisabled: Bool
  var title: String
  var action: () -> Void

  var body: some View {
    Button(action: action, label: {
      ZStack{
        RoundedRectangle(cornerRadius:20)
          .frame(
            width: UIScreen.main.bounds.width * 0.6,
            height: UIScreen.main.bounds.height * 0.08
          )
          .foregroundColor(isDisabled ? .gray : .black)
        Text(title)
          .foregroundColor(isDisabled ? .black : .white)
          .font(.title)
      }
    })
    .disabled(isDisabled)
  }
}
