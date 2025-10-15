//
//  TopBar.swift
//  BusRoad
//
//  Created by 박난 on 10/15/25.
//
import SwiftUI

struct TopBar: View {
    var isMoving: Bool
    var onXMark: () -> Void // coordinator.popToRoot()
    var body: some View {
        ZStack {
            HStack {
                Spacer()
                if isMoving {
                    Text("경로 이동")
                        .font(.papermed16)
                } else {
                    Text("경로 탐색")
                        .font(.papermed16)
                }
                Spacer()
            }
            HStack {
                Spacer()
                Button {
                    onXMark()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(.greyNormal)
                        .padding(.trailing, 20)
                }
            }
        }
//        .frame(height: 44)  // 높이 고정
    }
}

#Preview {
    TopBar(isMoving: true, onXMark: {})
}
