//
//  RecentCard.swift
//  BusRoad
//
//  Created by 박난 on 11/18/25.
//

import SwiftUI

struct RecentCard: View {
    var title: String
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.presemi20)
                    .foregroundStyle(.primaryblack)
                Spacer()
            }
            .padding(.horizontal, 23)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.primarywhite))
            )
        }
    }
}
