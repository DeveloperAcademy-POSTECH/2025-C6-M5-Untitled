//
//  RouteWalkCard.swift
//  BusRoad
//
//  Created by Youbin on 1/1/26.
//
import SwiftUI

struct RouteWalkCard: View {
    @ObservedObject var viewModel: BusRouteViewModel
    var journey: Journey
    
    // estimatedArrivalTime = 현재 시간 + totalTime
    var estimatedArrivalTime: String {
        let arrival = Date().addingTimeInterval(TimeInterval(journey.totalTime * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: arrival)
    }
    
    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(Color.primarywhite)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
            
            VStack(alignment: .leading, spacing: 75, content: {
                ETA(journeys: [journey], journey: journey, index: 0)
                walkNaviText
            })
        }
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
#Preview {
    let walkNode = WalkRouteNode(
        start: LocationInfo(name: "출발지", latitude: 37.0, longitude: 127.0),
        end: LocationInfo(name: "도착지", latitude: 37.1, longitude: 127.1),
        travelTime: 15  // 15분 도보
    )
    let journey = Journey(totalTime: 15, nodes: [.walk(walkNode)])
    let viewModel = BusRouteViewModel()
    return RouteWalkCard(viewModel: viewModel, journey: journey)
        .padding()
        .background(Color.gray.opacity(0.1))
}
