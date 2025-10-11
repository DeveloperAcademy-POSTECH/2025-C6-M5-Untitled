//
//  RouteCard.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCard: View {
    var journey: Journey
    
    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(Color.primaryNormal)
                .frame(width: 305, height: 423)
                .cornerRadius(20)
            if let firstBusRoute = journey.firstBusRoute {
                VStack(alignment:.leading){
                    Spacer()
                    ETA(journey: journey)
                    Spacer()
                    BoardingLocation(route: firstBusRoute)
                    Spacer()
                    RouteSummary(journey: journey)
                    Spacer()
                }
                .frame(width: 300, height: 423)
                .padding(.leading, 10)
            }
        }
    }
}
