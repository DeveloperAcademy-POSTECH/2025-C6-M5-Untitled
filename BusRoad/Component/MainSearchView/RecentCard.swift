//
//  RecentCard.swift
//  BusRoad
//
//  Created by 박난 on 11/18/25.
//

import SwiftUI

struct RecentCard: View {
    var title: String
    var onSelect: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(title)
                    .font(.presemi20)
                    .foregroundStyle(.primaryblack)
                Spacer()
                Button {
                    onDelete()
                } label: {
                    Image("xbutton")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30.wScaled, height: 30.wScaled)
                        .foregroundColor(.greyNormal)
                }
            }
            .padding(.leading, 23)
            .padding(.trailing, 12)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.primarywhite))
            )
        }
    }
}
