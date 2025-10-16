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
                        .font(.papermed18)
                } else {
                    Text("경로 탐색")
                        .font(.papermed18)
                }
                Spacer()
            }
            HStack {
                Spacer()
                Button {
                    onXMark()
                } label: {
                    Image("xbutton")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:44, height:44)
                        .foregroundColor(.greyNormal)
                }
            }
        }
//        .border(.black)
    }
}

#Preview {
    TopBar(isMoving: true, onXMark: {})
}
