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

            
            VStack(spacing: 28) {
                
                Image(systemName: "exclamationmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.greyDisable)
                
                errorMessageText
            }
        }
    }
    
    //MARK: - 에러메시지 텍스트
    private var errorMessageText: some View {
        VStack(alignment: .center, spacing: 20, content: {
            if viewModel.errorMessage == "지원하지 않는 교통수단이 포함되어 있습니다." {
                Text("지원하지 않는 경로예요")
                    .font(.presemi24)
                    .foregroundColor(Color.primaryHeavy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                
                Text("다른 장소를 검색해주세요")
                    .font(.premed20)
                    .foregroundColor(Color.primaryHeavy)
                
            } else if viewModel.errorMessage == "출발지와 도착지가 같습니다." {
                Text("출발지와 도착지가\n동일해요")
                    .font(.presemi24)
                    .foregroundColor(Color.primaryHeavy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                
                Text("다른 장소를 검색해주세요")
                    .font(.premed20)
                    .foregroundColor(Color.primaryHeavy)
                
            } else {
                Text("오류가 발생했어요")
                    .font(.presemi24)
                    .foregroundColor(Color.primaryHeavy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                
                Text("경로를 새로고침 해주세요")
                    .font(.premed20)
                    .foregroundColor(Color.primaryHeavy)
            }
        })
    }
}

// MARK: - 프리뷰
#Preview("지원하지 않는 교통수단") {
    let vm = BusRouteViewModel()
    vm.errorMessage = "지원하지 않는 교통수단이 포함되어 있습니다."
    return RouteErrorCard(viewModel: vm)
        .padding()
}

#Preview("출발지=도착지") {
    let vm = BusRouteViewModel()
    vm.errorMessage = "출발지와 도착지가 같습니다."
    return RouteErrorCard(viewModel: vm)
        .padding()
}

#Preview("기타 오류") {
    let vm = BusRouteViewModel()
    vm.errorMessage = "API 호출 실패"
    return RouteErrorCard(viewModel: vm)
        .padding()
}
