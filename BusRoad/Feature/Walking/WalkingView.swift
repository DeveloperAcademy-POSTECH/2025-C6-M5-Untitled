import SwiftUI
import MapKit

struct WalkingView: View {
    @ObservedObject var viewModel = WalkingViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @AppStorage("isFirstLaunching") var isFirstLaunching: Bool = true
    
    let languageCode = Locale.current.language.languageCode?.identifier
    
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
                            
                            if case let .walk(node) = journey.nodes[index] {
                                VStack(spacing: 8) {
                                    Text(index == journey.nodes.count - 1 ? "목적지까지 걷기" : "정류장까지 걷기")
                                        .font(.prereg20)
                                        .foregroundColor(.primaryHeavy)
                                    
                                    MarqueeText(
                                        text: languageCode == "ko" ? node.end.name : node.end.englishName ?? node.end.name,
                                        font: .presemi36Scaled,
                                        uiFont: .presemi36Scaled,
                                        startDelay: 1.0,
                                        alignment: .center
                                    )
                                    .foregroundColor(.primaryHeavy)
                                }
                                .padding(.top, 44.wScaled)
                                .padding(.horizontal, 32.wScaled)
                                Spacer()
                            }
                            
                            if viewModel.arrived {
                                VStack(spacing: 0) {
                                    
                                    Spacer()
                                    
                                    AtArrival(journey: journey, index: index, viewModel: viewModel)
                                    
                                    Spacer()
                                    
                                    Button {
                                        viewModel.stopAllAnnouncements()
                                        
                                        if index == journey.nodes.count - 1 {
                                            coordinator.popToRoot()
                                            ProgressLiveActivityManager.shared.endActivity()
                                        } else {
                                            coordinator.advanceJourneyStage()
                                            
                                            if journey.nodes.indices.contains(index + 1),
                                               case let .bus(busnode) = journey.nodes[index + 1] {
                                                let boardingStopName = busnode.start.name
                                                
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    Task {
                                                        await ProgressLiveActivityManager.shared.updateStage(
                                                            nextStage: RouteStage.waitingForBus.rawValue,
                                                            nextDestination: boardingStopName,
                                                            totalDistance: 0,
                                                            remainingBusStops: busnode.stations.count,
                                                            timeTillBusArrival: ArrivalInfoManager.shared.lastNearestArrTime ?? 0
                                                        )
                                                    }
                                                    print("[DEBUG] 확인 완료 - waitingForBus 업데이트, destination: \(boardingStopName)")
                                                }
                                            }
                                        }
                                    } label: {
                                        Text("맞아요")
                                            .foregroundColor(.white)
                                            .font(.premed32Scaled)
                                            .frame(width: 344.wScaled, height: 64.wScaled)
                                            .background(Color.subPoint)
                                            .cornerRadius(20)
                                    }
                                    .opacity(viewModel.showArrivalContent ? 1 : 0)
                                }
                            } else {
                                VStack(spacing: 30) {
                                    VStack(spacing: 0) {
                                        ToDestination(vm: viewModel, journey: journey, index: index)
                                            .padding(.bottom, 16.wScaled)
                                        
                                        Button {
                                            viewModel.stopAllAnnouncements()
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
                        .tint(.primarywhite)
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
                } else if isFirstLaunching {
                    OnboardingView(
                        isFirstLaunching: $isFirstLaunching,
                        viewModel: viewModel
                    )
                    .onAppear {
                        viewModel.finishedOnboarding.toggle()
                    }
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
            if !isFirstLaunching {
                viewModel.start()
            }
            
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
