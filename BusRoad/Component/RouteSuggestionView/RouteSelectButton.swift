//
//  routeSelectButton.swift
//  BusRoad
//
//  Created by 강진 on 10/12/25.
//

import SwiftUI

struct RouteSelectButton: View {
    //    @StateObject private var viewModel = BusRouteViewModel()
    @Binding var currentIndex: Int
    var errorMessage: String?
    var routes: [Journey]?
    var onSelect: () -> Void
    var retrySearch: () -> Void
    
    var body: some View {
        if errorMessage == nil {
            Button {
                if let routes {
                    print("[DEBUG] 버튼 클릭! 현재 index: \(currentIndex)")
                    onSelect()
                } else {
                    print("[DEBUG] routes가 존재하지 않습니다.")
                }
            } label: {
                
                Text("이걸로 갈게요")
                    .foregroundColor(Color.subLight)
                    .font(.premed32)
                    .frame(width: 240, height: 75)
                    .background(Color.subStrong)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            
        } else {
            Button {
                retrySearch()
            } label: {
                
                Text("다시 검색하기")
                    .foregroundColor(Color.subLight)
                    .font(.premed32)
                    .frame(width: 240, height: 75)
                    .background(Color.subStrong)
                    .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            
        }
    }
}
