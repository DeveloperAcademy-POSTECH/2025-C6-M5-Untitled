import SwiftUI

struct RouteCard: View {
    var allJourneys: [Journey]
    var journey: Journey
    var index: Int
    var isActive: Bool = true
    
    var body: some View {
        
        if let firstBusRoute = journey.firstBusRoute {
            
            ZStack {
                Rectangle()
                    .foregroundColor(Color.primaryNormal)
                    .cornerRadius(20)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 40.wScaled) {
                        
                        VStack(alignment: .leading, spacing: 36.wScaled) {
                            ETA(journeys: allJourneys, journey: journey, index: index)
                            BoardingLocation(route: firstBusRoute, isActive: isActive)
                        }
                        
                        RouteSummary(journey: journey)
                        
                    }
                    .padding(.horizontal, 24.wScaled)
                    Spacer()
                }
            }
        }
    }
}
