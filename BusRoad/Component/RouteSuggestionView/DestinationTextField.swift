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
            Text("도착")
                .foregroundColor(Color.subPoint)
                .font(.prereg20Scaled)
            
            Divider()
                .background(Color.greyDisable)
                .frame(width: 1)
                .frame(height: 26)
            
            Button(action: {
                locationType = .destination
                isSearchMode = true
                //        if let name = location?.name {
                //          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                //            NotificationCenter.default.post(
                //              name: .didSetPresetDestination,
                //              object: name
                //            )
                //          }
                //        }
            }) {
                HStack{
                    Text(location?.name.isEmpty == false ? location?.name ?? "" : "도착지를 입력하세요")
                        .foregroundColor(Color.greyHeavy)
                        .font(.prereg20Scaled)
                        .lineLimit(1)
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(.leading, 20)
        .padding(.trailing, 0)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .foregroundStyle(Color.background)
        }
    }
}


//extension Notification.Name {
//    static let didSetPresetDestination = Notification.Name("didSetPresetDestination")
//}

#Preview {
    @Previewable @State var location: LocationInfo? = .init(name: "아주 긴 텍스트는 어떻게 보이는지 보기위해서 아주 긴 텍스트를 입력합니다.", latitude: 0, longitude: 0)
    @Previewable @State var locationType: LocationType = .origin
    @Previewable @State var isSearchMode: Bool = false
    @Previewable @StateObject var coordinator: NavigationCoordinator = .init()
    DestinationTextField(
        location: $location,
        locationType: $locationType,
        isSearchMode: $isSearchMode
    )
    .environmentObject(coordinator)
}
