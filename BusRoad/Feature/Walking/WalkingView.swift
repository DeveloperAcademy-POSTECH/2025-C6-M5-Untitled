import SwiftUI
import MapKit

struct WalkingView: View {
    @ObservedObject var viewModel = WalkingViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    var body: some View {
        ZStack {
            Color(.primarywhite).ignoresSafeArea()
            
            VStack(spacing: 0){
                VStack(spacing: 0) {
                    TopBar(isMoving: true) { coordinator.popToRoot() }
                        .padding(.horizontal, 8)
                    
                    if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                        WholeJourney(journey: journey, journeyIndex: index, isBeforeRide: false)
                            .padding(32)
                    }
                }
                .frame(height: 144)
                .onChange(of: viewModel.arrived) { _, newValue in
                    if newValue,
                       let journey = viewModel.journey,
                       let index = viewModel.journeyIndex,
                       index == journey.nodes.count - 1 {
                        coordinator.advanceJourneyStage()
                    }
                }
              
                LineDivider()
                
                ZStack {
                    Color(.background).ignoresSafeArea()
                    VStack {
                        if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                            if viewModel.arrived {
                                AtArrival(journey: journey, index: index, viewModel: viewModel)
                            } else {
                                ToDestination(vm:viewModel, journey: journey, index: index)
                                Spacer()
                                Button {
                                    viewModel.showAlert = true
                                } label: {
                                    if index == journey.nodes.count - 1 {
                                        Text("이미 목적지에 도착하셨나요?")
                                            .font(.premed14Scaled)
                                            .foregroundColor(.primaryHeavy)
                                            .underline()
                                    } else {
                                        Text("이미 정류장에 도착하셨나요?")
                                            .font(.premed14Scaled)
                                            .foregroundColor(.primaryHeavy)
                                            .underline()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 맵뷰 버튼
            VStack {
                Spacer().frame(height: 144 + 120.wScaled) // 높이 144(고정) + 120.wScaled(변동)
                HStack {
                    Spacer()
                    Button {
                        viewModel.showDevSheet = true
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.system(size: 20.wScaled, weight: .bold))
                            .foregroundColor(.subLight)
                            .padding(.vertical, 12.wScaled)
                            .padding(.horizontal, 18.wScaled)
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 10,
                                    bottomLeadingRadius: 10
                                ).fill(Color.subPoint)
                            )
                    }
                }
                Spacer()
            }
            .overlay {
                if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                    WalkingAlert(isPresented: $viewModel.showAlert,
                                 viewModel: viewModel,
                                 journey: journey,
                                 index: index)
                }
            }
            
            if viewModel.isRerouting {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("경로 재탐색 중…")
                        .font(.callout)
                        .foregroundColor(.white)
                }
                .padding(16)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .overlay(alignment: .center) {
            Group {
                if let journey = viewModel.journey,
                   let index = viewModel.journeyIndex,
                   viewModel.showRerouteAlert {
                    WalkingRerouteAlert(
                        isPresented: $viewModel.showRerouteAlert,
                        viewModel: viewModel,
                        journey: journey,
                        index: index
                    )
                } else {
                    EmptyView()
                }
            }
        }
        // 맵뷰 바텀 시트
        .sheet(isPresented: $viewModel.showDevSheet) {
            DevRouteMapView(
                tmapCoordinates: viewModel.tmapCoordinates,
                userLocation: viewModel.loc.location,
                destination: viewModel.pendingDestination,
                deviceHeading: viewModel.loc.heading?.trueHeading
            )
            .presentationDetents([.fraction(0.4), .large])
            .presentationDragIndicator(.visible)
        }
    }
}
