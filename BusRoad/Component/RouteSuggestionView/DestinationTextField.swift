//
//  DestinationTextField.swift
//  BusRoad
//
//  Created by 강진 on 9/28/25.
//

import SwiftUI

struct DestinationTextField : View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Binding var location: LocationInfo?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerSize: .init(width: 25, height: 25))
                .stroke(Color.subStrong)
                .frame(width: 350, height:50)
            
          HStack(spacing: 10){
                Text("도착지")
                    .foregroundColor(Color.subPoint)
                    .font(.prereg20)
                    .padding(.leading, 30)
                Divider()
                  .background(Color.greyDisable)
              
                Button(action: {
                    // TODO: 임시 내비게이션
                    coordinator.push(.mainSearch)
                }) {
                    Text(location?.name.isEmpty == false ? location?.name ?? "" : "도착지를 입력하세요")
                        .foregroundColor(Color.greyHeavy)
                        .font(.prereg20)
                }
                Spacer()
            }
            .frame(height: 30)
        }
    }
}
