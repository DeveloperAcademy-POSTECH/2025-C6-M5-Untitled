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
                            .padding(.horizontal, 32)
                            .padding(.vertical,24)
                    }
                }
                .frame(height: 128)
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
                    VStack(spacing: 0) {
                        if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                            if viewModel.arrived {
                                AtArrival(journey: journey, index: index, viewModel: viewModel)
                            } else {
                                VStack(spacing: 30) {
                                    VStack(spacing: 0) {
                                        ToDestination(vm: viewModel, journey: journey, index: index)
                                            .padding(.top, 44.wScaled)
                                            .padding(.bottom, 16.wScaled)
                                        
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
                                    
                                    HStack {
                                        Spacer()
                                        Button {
                                            viewModel.showDevSheet = true
                                        } label: {
                                            HStack(spacing: 8.wScaled) {
                                                Image(systemName: "map.fill")
                                                    .font(.presemi18)
                                                Text("지도")
                                                    .font(.presemi18)
                                            }
                                            .foregroundColor(.primaryHeavy)
                                            .padding(.vertical, 14.wScaled)
                                            .padding(.horizontal, 21.wScaled)
                                            .background(
                                                Capsule()
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 0)
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 21.wScaled)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if let journey = viewModel.journey, let index = viewModel.journeyIndex {
                    WalkingAlert(
                        isPresented: $viewModel.showAlert,
                        viewModel: viewModel,
                        journey: journey,
                        index: index
                    )
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
                if viewModel.showRerouteAlert {
                    WalkingRerouteAlert(
                        isPresented: $viewModel.showRerouteAlert,
                        viewModel: viewModel
                    )
                } else {
                    EmptyView()
                }
            }
        }
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
        .onAppear {
            viewModel.start()
            
            // Journey에서 목적지 설정
            if let journey = viewModel.journey,
               let index = viewModel.journeyIndex {
                if case .walk(let node) = journey.nodes[index] {
                    viewModel.setDestination(from: node)
                }
            }
        }
    }
}
