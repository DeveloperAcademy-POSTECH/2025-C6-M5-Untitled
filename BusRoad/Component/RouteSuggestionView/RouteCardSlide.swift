//
//  RouteCardSlide.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCardSlide: View {
    @Binding var currentIndex: Int
    @Binding var routes: [Journey]?
    @ObservedObject var viewModel: BusRouteViewModel
    var errorMessage: String?
        
    var body: some View {
        ZStack {
          if errorMessage != nil {
            RouteErrorCard(viewModel: viewModel)
            } else if let routes {
                ZStack {
                    ForEach(Array(routes.enumerated()), id: \.element.id) { index, item in
                        let relativeIndex: CGFloat = CGFloat(index - currentIndex)
                        RouteCard(journey: item, index: index)
                            .offset(x: relativeIndex * 270.wScaled)
                            .scaleEffect(relativeIndex == 0 ? 1.0 : 0.9)
                            .opacity(relativeIndex == 0 ? 1.0 : 0.3)
                            .zIndex(Double(routes.count) - Double(abs(index - currentIndex)))
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
                .animation(.spring(), value: currentIndex)
            } else {
                ProgressRouteCard()
            }
        }
    }
}
