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
        ZStack{
            Rectangle()
                .foregroundColor(Color.primaryNormal)
                .frame(width: 305, height: 423)
                .cornerRadius(20)
            if let firstBusRoute = journey.firstBusRoute {
                VStack(alignment:.leading){
                    ETA(journey: journey, index: index)
                    Spacer()
                    BoardingLocation(route: firstBusRoute)
                    Spacer()
                    RouteSummary(journey: journey)
                    .padding(.bottom, 30)
                }
                .frame(width: 290, height: 400)
                .padding(.leading, 20)
            }
        }
    }
}
