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
    @State var currentIndex = 0

    var body: some View {
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

            routeSelectButton

            if viewModel.routes == nil {
                Text("현재 위치를 가져오는 중...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding([.leading, .trailing, .bottom], 10)
        .background(Color.gray.opacity(0.01))
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

    var routeSelectButton: some View {

        return Button(
            action: {
                if let routes = viewModel.routes {
                    print("[DEBUG] 버튼 클릭! 현재 index: \(currentIndex)")
                    viewModel.selectJourney(at: currentIndex)
                    coordinator.push(.walking)  // TODO: 임시 내비게이션
                }
            },
            label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: 240, height: 75)
                        .foregroundColor(Color.subStrong)
                    Text("이걸로 갈게요")
                        .foregroundColor(Color.subLight)
                        .font(.premed32)
                }
            }
        )
    }
}

#Preview {
    RouteSuggestionView()
        .environmentObject(NavigationCoordinator())
}
