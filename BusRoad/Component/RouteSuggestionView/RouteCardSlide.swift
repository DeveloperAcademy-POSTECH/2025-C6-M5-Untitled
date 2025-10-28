import SwiftUI

struct RouteCardSlide: View {
    @Binding var currentIndex: Int
    @Binding var routes: [Journey]?
    @ObservedObject var viewModel: BusRouteViewModel
    var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if errorMessage != nil {
                    RouteErrorCard(viewModel: viewModel)
                } else if let routes {
                    ZStack {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, item in
                            let relativeIndex: CGFloat = CGFloat(index - currentIndex)
                            RouteCard(allJourneys: routes,
                                      journey: item,
                                      index: index,
                                      isActive: currentIndex == index
                            )
                            .offset(x: relativeIndex * 270.wScaled)
                            .scaleEffect(relativeIndex == 0 ? 1.0 : 0.9)
                            .opacity(relativeIndex == 0 ? 1.0 : 0.3)
                            .zIndex(Double(routes.count) - Double(abs(index - currentIndex)))
                            .animation(.spring(), value: currentIndex)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if abs(value.translation.width) < 50 {
                                    return
                                }
                                
                                if value.translation.width > 0 {
                                    currentIndex = max(0, currentIndex - 1)
                                } else {
                                    currentIndex = min(routes.count - 1, currentIndex + 1)
                                }
                            }
                    )
                } else {
                    ProgressRouteCard()
                }
            }
            
            // 항상 28 높이의 공간 차지
            if let routes = routes, routes.count > 1 {
                HStack {
                    ForEach(0..<routes.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.greyStrong : Color.greyStrong.opacity(0.3))
                            .frame(width: 8.wScaled, height: 8.wScaled)
                    }
                }
                .frame(height: 28.wScaled)
            } else {
                // 에러나 로딩 상태일 때도 동일한 높이 유지
                Color.clear
                    .frame(height: 28.wScaled)
            }
        }
    }
}
