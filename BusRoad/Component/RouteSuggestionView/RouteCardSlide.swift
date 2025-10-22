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
    
//    private let cardWidth: CGFloat = 305.wScaled
        
    var body: some View {
      VStack(spacing: 8) {
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
        
        if let routes = routes, routes.count > 1 {
          HStack {
            ForEach(0..<routes.count, id: \.self) { index in
              Circle()
                .fill(index == currentIndex ? Color.greyStrong : Color.greyStrong.opacity(0.3))
                .frame(width: 8.wScaled, height: 8.wScaled)
            }
          }
          .padding(.top, 8.wScaled)
        }
      }
    }
}
