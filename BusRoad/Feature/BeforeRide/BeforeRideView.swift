//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import SwiftUI

struct BeforeRideView: View {
  @State private var isBusArriveSoon: Bool = true
  
  var body: some View {
    Card(isActive: isBusArriveSoon, busStop: "대구북편네거리", instruction: "정류장에서 타야 해요")
    CustomButton(isDisabled: true, title: "탔어요", action: { })
  }
}
