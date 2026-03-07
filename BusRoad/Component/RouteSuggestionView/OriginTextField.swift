//
//  OriginTextField.swift
//  BusRoad
//
//  Created by 강진 on 9/28/25.
//

import SwiftUI

struct OriginTextField : View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Binding var location: LocationInfo?
    @Binding var isSearchMode: Bool
    @Binding var locationType: LocationType
    @Binding var userDidSelectOrigin: Bool
    @Binding var isRefreshingLocation: Bool
    
    @State private var rotationAngle: Double = 0  // 회전 각도
    var onRefreshTapped: () async -> Void
    
    var body: some View {
        
        HStack(spacing: 12) {
            Text("출발")
                .foregroundColor(Color.subPoint)
                .font(.prereg20Scaled)
                .frame(width: 60.wScaled, alignment: .leading)

            Divider()
                .background(Color.greyDisable)
                .frame(width: 1)
                .frame(height: 26)
            
            Button(action: {
                locationType = .origin
                isSearchMode = true
            }) {
                HStack{
                    Text(location?.name ?? NSLocalizedString("현위치", comment: "현위치")) //플레이스홀더
                        .font(.prereg20Scaled)
                        .foregroundColor(userDidSelectOrigin ? .greyHeavy : .greyDisable)
                    Spacer()
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    await onRefreshTapped()
                }
            } label: {
                Image("update")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color.greyNormal)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(rotationAngle))
            }
            .disabled(isRefreshingLocation)
        }
        .padding(.leading, 20)
        .padding(.trailing, 15)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .foregroundStyle(Color.background)
            
        }
        .task(id: isRefreshingLocation) {
            // ⭐ task는 id가 변경되면 자동으로 취소됨
            if isRefreshingLocation {
                while !Task.isCancelled {
                    withAnimation(.linear(duration: 0.5)) {
                        rotationAngle += 360
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            } else {
                // 멈춤
                rotationAngle = 0
            }
        }
    }
}
