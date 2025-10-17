//
//  RouteCard.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCard: View {
    var journey: Journey
    var index: Int
    
    var body: some View {
        
        if let firstBusRoute = journey.firstBusRoute {
            ZStack {
                Rectangle()
                    .foregroundColor(Color.primaryNormal)
                    .cornerRadius(20)
                
                VStack (spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 40) {
                        
                        VStack(alignment: .leading, spacing: 36) {
                            ETA(journey: journey, index: index)
                            BoardingLocation(route: firstBusRoute)
                        }
                        
                        RouteSummary(journey: journey)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            
        }

    }
}

#Preview {
    // MARK: - 더미 데이터
    let start = LocationInfo(name: "포항공대 정문", latitude: 36.015149, longitude: 129.325116)
    let transferStop = LocationInfo(name: "중앙로 환승", latitude: 36.0348, longitude: 129.3340)
    let finalStop = LocationInfo(name: "포항역", latitude: 36.07160518, longitude: 129.3419282)
    
    let leg1 = BusRouteNode(
        start: start,
        end: transferStop,
        busNo: "105",
        busId: 105,
        stations: [],
        travelTime: 18
    )
    let walk = WalkRouteNode(
        start: transferStop,
        end: LocationInfo(name: "버스2 정류장", latitude: 36.0350, longitude: 129.3343),
        travelTime: 5
    )
    let leg2 = BusRouteNode(
        start: walk.end,
        end: finalStop,
        busNo: "200",
        busId: 200,
        stations: [],
        travelTime: 22
    )
    
    let sampleJourney = Journey(
        totalTime: 18 + 5 + 22,
        nodes: [.bus(leg1), .walk(walk), .bus(leg2)]
    )
    
    return RouteCard(journey: sampleJourney, index: 0)
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color(.systemBackground))
}
