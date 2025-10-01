//
//  DestinationTextFieldView.swift
//  BusRoad
//
//  Created by 강진 on 9/28/25.
//

import SwiftUI

struct DestinationTextField : View {
    @Binding var location: LocationInfo?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerSize: .init(width: 10, height: 10))
                .stroke(Color.black)
                .frame(height:50)
            
            HStack{
                Text("도착지")
                    .padding(.leading, 10)
                Divider()
                
                TextField(
                    "도착지를 입력하세요",
                    text: Binding(
                        get: { self.location?.name ?? "" },
                        set: { newName in
                            if self.location == nil {
                                self.location = LocationInfo(name: newName, longitude: 0, latitude: 0)
                            } else {
                                self.location?.name = newName
                            }
                        }
                    )
                )
                Spacer()
            }
            .frame(height: 30)
        }
    }
}
