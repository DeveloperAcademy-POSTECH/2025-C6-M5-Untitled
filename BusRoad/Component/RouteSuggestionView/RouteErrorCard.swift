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
        .foregroundColor(Color.primaryNormal)
        .cornerRadius(20)
        .frame(height: 430.wScaled)
      VStack(spacing: 8) {
        if viewModel.errorMessage == "출발지와 목적지가 너무 가깝습니다." {
          Text("출발지와 도착지가\n가까이 있어요!")
            .font(.presemi24)
            .foregroundColor(Color.subLight)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
          
          Text("도보 경로 안내를 시작할게요.")
            .font(.premed20)
            .foregroundColor(Color.subLight)
          
        } else if viewModel.errorMessage == "지원하지 않는 교통수단이 포함되어 있습니다." {
          Text("현재 경로는\n지원하지 않아요😵")
            .font(.presemi24)
            .foregroundColor(Color.subLight)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
          
          Text("다른 장소를 검색해주세요.")
            .font(.premed20)
            .foregroundColor(Color.subLight)
          
        } else if viewModel.errorMessage == "출발지와 도착지가 같습니다." {
          Text("출발지와 도착지가\n같은 곳이에요😵")
            .font(.presemi24)
            .foregroundColor(Color.subLight)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
          
          Text("다시 검색해주세요.")
            .font(.premed20)
            .foregroundColor(Color.subLight)
          
        } else {
          Text("앗, 문제가 발생했어요😵")
            .font(.presemi24)
            .foregroundColor(Color.subLight)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
          
          Text("경로를 새로고침 해주세요.")
            .font(.premed20)
            .foregroundColor(Color.subLight)
        }
      }
    }
  }
}
