import SwiftUI

struct AtArrival: View {
    var journey: Journey
    var index: Int
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    @State private var scale: CGFloat = 0.0
    @State private var isAnimating = false
    @State private var showVerifyingStop = false

    var body: some View {
        if case let .walk(node) = journey.nodes[index] {
            if showVerifyingStop {
              VerifyingStop(showVerifyingStop: $showVerifyingStop, journey: journey, index: index)
            } else {
              VStack(alignment: .leading) {
                    Spacer()
                    Text(node.end.name)
                        .font(.presemi36)
                        .foregroundColor(.primaryHeavy)
                    
                    Spacer()
                    
                HStack{
                  Spacer()
                  Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 148, weight: .bold))
                    .foregroundColor(.subStrong)
                    .rotation3DEffect(
                      .degrees(isAnimating ? 360 : 0),
                      axis: (x: 0, y: 1, z: 0)
                    )
                    .onAppear {
                      withAnimation(.easeOut(duration: 2.0)) {
                        isAnimating = true
                      }
                      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        showVerifyingStop = true
                      }
                    }
                  Spacer()
                }
                    Spacer()
                    
                    Text("도착")
                        .font(.presemi32)
                        .foregroundColor(.primaryHeavy)
                    Text("했어요!")
                        .font(.prereg32)
                        .foregroundColor(.primaryHeavy)
                        .padding(.bottom, 80)
                }
              .padding(.horizontal,30)
            }
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36)
                .foregroundColor(.red)
        }
    }
}
