import SwiftUI

struct RouteCard: View {
    @ObservedObject var viewModel: BusRouteViewModel

    @State private var didFetchOnce = false
    @State private var nearestBusInfo: (busNo: String, arrivalText: String)?
    
    var allJourneys: [Journey]
    var journey: Journey
    var index: Int
    var isActive: Bool = true
    
    var body: some View {
        
        if let firstBusRoute = journey.firstBusRoute {
            ZStack {
                Rectangle()
                    .foregroundColor(Color.primarywhite)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
                if !didFetchOnce{
                    ProgressView()
                        .tint(.greyDisable)
                        .scaleEffect(3)
                } else {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 21.wScaled) {
                            VStack(alignment: .leading, spacing: 45.wScaled) {
                                ETA(journeys: allJourneys, journey: journey, index: index)
                                BoardingLocation(route: firstBusRoute, isActive: isActive, nearestBusInfo: $nearestBusInfo)
                            }
                                                    
                            RouteSummary(journey: journey)
                            
                        }
                        .padding(.horizontal, 24.wScaled)
                        
                        Spacer()
                    }
                }
            }
            .onAppear {
                if !didFetchOnce {
                    Task {
                        nearestBusInfo = await viewModel.fetchNearestBusInfo(for: firstBusRoute)
                        didFetchOnce = true
                    }
                }
            }
        }
    }
}




#Preview {
    @Previewable var previewBusInfo: (busNo: String, arrivalText: String)? = nil

    RouteCard(
        viewModel: BusRouteViewModel(),
        allJourneys: [
            Journey(totalTime: 48, nodes: [
                .walk(WalkRouteNode(
                    start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02),
                    travelTime: 5
                )),
                .bus(BusRouteNode(
                    start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                    end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02),
                    busNo: ["405", "472"],
                    busId: [1001, 1002],
                    stations: [
                        BusStation(index: 0, stationId: 111, stationName: "서울역", stationCityCode: 1100, localStationId: "LOCAL-SEOUL-001", nodeId: "1000001", latitude: 37.55, longitude: 126.97),
                        BusStation(index: 1, stationId: 222, stationName: "강남역", stationCityCode: 1100, localStationId: "LOCAL-GANGNAM-001", nodeId: "1000002", latitude: 37.49, longitude: 127.02)
                    ],
                    travelTime: 35
                ))
            ])
        ],
        journey: Journey(totalTime: 48, nodes: [
            .walk(WalkRouteNode(
                start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02),
                travelTime: 5
            )),
            .bus(BusRouteNode(
                start: LocationInfo(name: "서울역", latitude: 37.55, longitude: 126.97),
                end: LocationInfo(name: "강남역", latitude: 37.49, longitude: 127.02),
                busNo: ["472"],
                busId: [1001],
                stations: [
                    BusStation(index: 0, stationId: 111, stationName: "서울역", stationCityCode: 1100, localStationId: "LOCAL-SEOUL-001", nodeId: "1000001", latitude: 37.55, longitude: 126.97),
                    BusStation(index: 1, stationId: 222, stationName: "강남역", stationCityCode: 1100, localStationId: "LOCAL-GANGNAM-001", nodeId: "1000002", latitude: 37.49, longitude: 127.02)
                ],
                travelTime: 35
            ))
        ]),
        index: 0
    )
}
