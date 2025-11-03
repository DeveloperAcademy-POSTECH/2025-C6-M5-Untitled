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
                .foregroundColor(Color.primarywhite)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryLight))
                .scaleEffect(3)
        }
    }
}
#Preview {
    ProgressRouteCard()
}
