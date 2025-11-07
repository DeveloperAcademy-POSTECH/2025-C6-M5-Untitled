import SwiftUI
import Lottie

struct AtArrival: View {
    var journey: Journey
    var index: Int
    @EnvironmentObject var coordinator: NavigationCoordinator
    @ObservedObject var viewModel: WalkingViewModel
    
    @State private var scale: CGFloat = 0.0
    @State private var isAnimating = false
    @State private var showVerifyingStop = false
    
    var body: some View {
        if case let .walk(node) = journey.nodes[index] {
            if viewModel.showVerifyingStop && journey.nodes.count > 1 {
                VerifyingStop(showVerifyingStop: $viewModel.showVerifyingStop, journey: journey, index: index)
            } else {
                VStack(alignment: .leading) {
                    Spacer()
                    
                    MarqueeText(
                        text: node.end.name,
                        font: .presemi36Scaled,
                        uiFont: .presemi36Scaled,
                        startDelay: 1.0,
                        alignment: .leading,
                    )
                    .foregroundColor(.primaryHeavy)
                    
                    Spacer()
                    
                    HStack{
                        Spacer()
                        
                        LottieView(animation: .named("check"))
                            .playing(loopMode: .playOnce)
                            .animationSpeed(1.0)
                            .frame(width: 180, height: 180)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    showVerifyingStop = true
                                }
                            }
                        
                        Spacer()
                    }
                    Spacer()
                    
                    Text("도착")
                        .font(.presemi32Scaled)
                        .foregroundColor(.primaryHeavy)
                    Text("했어요!")
                        .font(.prereg32Scaled)
                        .foregroundColor(.primaryHeavy)
                        .padding(.bottom, 80.wScaled)
                }
                .padding(.horizontal,30.wScaled)
            }
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36Scaled)
                .foregroundColor(.red)
        }
    }
}


#Preview {
    // Mock data: a journey with a single walk node ending at a named stop
    let start = LocationInfo(name: "출발지", latitude: 37.0, longitude: 127.0)
    let end = LocationInfo(name: "포스텍 정문", latitude: 36.0, longitude: 129.0)
    let walk = WalkRouteNode(start: start, end: end, travelTime: 5)
    let journey = Journey(totalTime: 5, nodes: [.walk(walk)])

    let coordinator = NavigationCoordinator()
    return AtArrival(journey: journey, index: 0)
        .environmentObject(coordinator)
        .padding()
}
