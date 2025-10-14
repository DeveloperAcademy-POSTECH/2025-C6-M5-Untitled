//
//  Untitled.swift
//  BusRoad
//
//  Created by 박난 on 9/23/25.
//

import CoreLocation
import SwiftUI

struct RouteSuggestionView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = BusRouteViewModel()
    @State private var user = User(isOnBus: false)
    @State var currentIndex: Int = 0

    var body: some View {
      ZStack{
        Rectangle()
          .fill(Color.background)
          .stroke(Color.greyDisable, lineWidth: 0.5)
          .frame(maxWidth: .infinity, maxHeight: 615)
          .offset(y: UIScreen.main.bounds.height / 2 - 615 / 2 - 10)
        VStack{
            Text("경로 선택")
                .font(.papermed16)
                .padding(.bottom, 10)
            OriginTextField(
                location: $viewModel.origin,
                onRefreshTapped: { viewModel.requestOrigin() }
            )
          
            DestinationTextField(location: $viewModel.destination)

            RouteCardSlide(
                currentIndex: $currentIndex,
                routes: viewModel.routes,
                errorMessage: viewModel.errorMessage
            )
            .padding([.top, .bottom], 20)

            RouteSelectButton(currentIndex: $currentIndex,
                              errorMessage: viewModel.errorMessage,
                              routes: viewModel.getJourneyList(),
                              onSelect: {
                viewModel.selectJourney(at: currentIndex)
                coordinator.push(.journeyFlow)
            },
                              retrySearch: {
                print(viewModel.errorMessage)
                coordinator.popToRoot() // MainSearch로 초기화
            }
                              
            )

            if viewModel.routes == nil {
                Text("현재 위치를 가져오는 중...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding([.leading, .trailing, .bottom], 10)
        .onAppear {
            viewModel.requestOrigin()
            user.currentLocation = viewModel.origin?.coordinate
        }
        .onChange(of: viewModel.origin) { _, newOrigin in
            print("[DEBUG] origin updated")
            viewModel.validateAndFetchRoute(
                origin: newOrigin,
                destination: viewModel.destination
            )
        }
        .onChange(of: viewModel.destination) { _, newDestination in
            print("[DEBUG] destination updated")
            viewModel.validateAndFetchRoute(
                origin: viewModel.origin,
                destination: newDestination
            )
        }
        .onChange(of: viewModel.routes) { _, _ in
            print("[DEBUG] routes updated")
            currentIndex = 0
        }
      }
    }
}

#Preview {
    RouteSuggestionView()
        .environmentObject(NavigationCoordinator())
}
