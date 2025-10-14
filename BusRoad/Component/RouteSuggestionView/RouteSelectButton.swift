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
            Button(
                action: {
                    if let routes {
                        print("[DEBUG] 버튼 클릭! 현재 index: \(currentIndex)")
                        onSelect()
                    } else {
                        print("[DEBUG] routes가 존재하지 않습니다.")
                    }
                },
                label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: 240, height: 75)
                            .foregroundColor(Color.subStrong)
                        Text("이걸로 갈게요")
                            .foregroundColor(Color.subLight)
                            .font(.premed32)
                    }
                }
            )
        } else {
            Button(
                action: {
                    retrySearch()
                },
                label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: 240, height: 75)
                            .foregroundColor(Color.subStrong)
                        Text("다시 검색하기")
                            .foregroundColor(Color.subLight)
                            .font(.premed32)
                    }
                }
            )
        }
    }
}
