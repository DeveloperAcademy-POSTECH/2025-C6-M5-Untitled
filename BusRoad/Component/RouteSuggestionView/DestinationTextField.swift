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
    @Binding var locationType: LocationType
    @Binding var isSearchMode: Bool
    
    var body: some View {
            
          HStack(spacing: 12) {
                Text("도착지")
                    .foregroundColor(Color.subPoint)
                    .font(.prereg20)
              
                Divider()
                  .background(Color.greyDisable)
                  .frame(height: 26)
              
                Button(action: {
                    locationType = .destination
                    isSearchMode = true
                }) {
                  HStack{
                    Text(location?.name.isEmpty == false ? location?.name ?? "" : "도착지를 입력하세요")
                      .foregroundColor(Color.greyHeavy)
                      .font(.prereg20)
                    Spacer()
                  }
                }
                Spacer()
            }
          .padding(.leading, 20)
          .padding(.trailing, 12)
          .padding(.vertical, 12)
          .overlay {
              RoundedRectangle(cornerRadius: 25)
                  .stroke(.subStrong, lineWidth: 1.5)
          }
    }
}
