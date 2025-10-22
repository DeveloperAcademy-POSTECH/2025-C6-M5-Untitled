//
//  ProgressRouteCard.swift
//  BusRoad
//
//  Created by 박난 on 10/15/25.
//
import SwiftUI

struct ProgressRouteCard: View {
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.primaryNormal)
//                .frame(width: 305, height: 423)
                .cornerRadius(20)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryLight))
                .scaleEffect(1.5)
        }
    }
}
#Preview {
    ProgressRouteCard()
}
