//
//  RouteCard.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCard: View {
    var journey: Journey
    var isFirstCard: Bool
    
    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(.gray)
                .frame(width: 317, height: 400)
                .cornerRadius(20)
            if let firstBusRoute = journey.firstBusRoute {
                VStack(alignment:.leading){
                    Spacer()
                    ETA(journey: journey, isFirstCard: isFirstCard)
                    Spacer()
                    BoardingLocation(route: firstBusRoute)
                    Spacer()
                    WholeJourney(journey: journey)
                    Spacer()
                }
                .frame(width: 317, height: 400)
                .padding(.leading, 5)
            }
        }
    }
}
