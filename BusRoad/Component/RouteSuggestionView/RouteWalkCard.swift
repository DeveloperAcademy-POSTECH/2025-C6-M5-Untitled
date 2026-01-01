//
//  RouteWalkCard.swift
//  BusRoad
//
//  Created by Youbin on 1/1/26.
//
import SwiftUI

struct RouteWalkCard: View {
    @ObservedObject var viewModel: BusRouteViewModel
    
    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(Color.primarywhite)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
            
            VStack(alignment: .leading, spacing: 75, content: {
                walkInfo
                walkNaviText
            })
        }
    }
    
    private var walkInfo: some View {
        VStack(alignment: .leading, spacing: 4, content: {
            
            Text("최적")
                .foregroundStyle(.subPoint)
                .font(.presemi20Scaled)
                .padding(.bottom, 3)
            
            
            Text("도보 12분")
                .font(.presemi32)
                .foregroundStyle(Color.primaryHeavy)
            
            Text("14:20 도착 예정")
                .foregroundStyle(Color.greyNormal)
                .font(.prereg16Scaled)
        })
    }
    
    private var walkNaviText: some View {
        VStack(alignment: .leading, spacing: 16, content: {
            Divider().frame(width: 250)
                .padding(.bottom, 30)
            
            ZStack{
                Circle()
                    .stroke(Color.subPoint, lineWidth: 1.5)
                    .frame(width: 28.wScaled.minimum(28), height:28.wScaled.minimum(28))
                
                Image(systemName: "figure.walk")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width:16.wScaled, height:16.wScaled)
                    .foregroundStyle(Color.subPoint)
            }
            
            Text("가장 빠른\n도보 경로로 안내해요")
                .font(.presemi24Scaled)
                .padding(.bottom, 30)
        })
    }
}

// MARK: - 프리뷰
#Preview("도보 경로 예시") {
    let vm = BusRouteViewModel()
    vm.origin = LocationInfo(name: "서울역", latitude: 37.5547125, longitude: 126.9707878)
    vm.destination = LocationInfo(name: "시청역", latitude: 37.565135, longitude: 126.976889)
    vm.createWalkingJourneyIfNeeded()
    return RouteWalkCard(viewModel: vm)
        .padding()
}
