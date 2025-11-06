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
    
    var onRefreshTapped: () -> Void
    
    var body: some View {
        
        HStack(spacing: 12) {
            Text("출발")
                .foregroundColor(Color.subPoint)
                .font(.prereg20Scaled)
            
            Divider()
                .background(Color.greyDisable)
                .frame(width: 1)
                .frame(height: 26)
            
            Button(action: {
                locationType = .origin
                isSearchMode = true
                //        if let name = location?.name, name != "현위치" {
                //          let searchText = (name == "현위치") ? "" : name
                //          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                //            NotificationCenter.default.post(
                //              name: .didSetPresetDestination,
                //              object: searchText
                //            )
                //          }
                //        }
            }) {
                HStack{
                    Text(location?.name ?? "현위치") //플레이스홀더
                        .font(.prereg20Scaled)
                        .foregroundColor(userDidSelectOrigin ? .greyHeavy : .greyDisable)
                    Spacer()
                }
            }
            
            Spacer()
            
            Button(action: {
                self.onRefreshTapped()
            }, label: {
                Image("update")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color.greyNormal)
                    .frame(width: 24, height: 24)
            })
        }
        .padding(.leading, 20)
        .padding(.trailing, 15)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .foregroundStyle(Color.background)
               
        }
    }
}
