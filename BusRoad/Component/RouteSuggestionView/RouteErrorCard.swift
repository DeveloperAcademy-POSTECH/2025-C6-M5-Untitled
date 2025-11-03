//
//  RouteErrorCard.swift
//  BusRoad
//
//  Created by 강진 on 10/12/25.
//

import SwiftUI

struct RouteErrorCard: View {
    @ObservedObject var viewModel: BusRouteViewModel
    
    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(Color.primarywhite)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
            
            VStack(spacing: 8) {
                if viewModel.errorMessage == "출발지와 목적지가 너무 가깝습니다." {
                    Text("출발지와 도착지가\n가까이 있어요!")
                        .font(.presemi24)
                        .foregroundColor(Color.primaryHeavy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                    
                    Text("도보 경로로 안내할게요.")
                        .font(.premed20)
                        .foregroundColor(Color.primaryHeavy)
                    
                } else if viewModel.errorMessage == "지원하지 않는 교통수단이 포함되어 있습니다." {
                    Text("현재 경로는\n지원하지 않아요😵")
                        .font(.presemi24)
                        .foregroundColor(Color.primaryHeavy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                    
                    Text("다른 장소를 검색해주세요.")
                        .font(.premed20)
                        .foregroundColor(Color.primaryHeavy)
                    
                } else if viewModel.errorMessage == "출발지와 도착지가 같습니다." {
                    Text("출발지와 도착지가\n같은 곳이에요😵")
                        .font(.presemi24)
                        .foregroundColor(Color.primaryHeavy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                    
                    Text("다시 검색해주세요.")
                        .font(.premed20)
                        .foregroundColor(Color.primaryHeavy)
                    
                } else {
                    Text("앗, 문제가 발생했어요😵")
                        .font(.presemi24)
                        .foregroundColor(Color.primaryHeavy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                    
                    Text("경로를 새로고침 해주세요.")
                        .font(.premed20)
                        .foregroundColor(Color.primaryHeavy)
                }
            }
        }
    }
}
