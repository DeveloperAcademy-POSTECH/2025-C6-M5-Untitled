//
//  RouteCardSlide.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCardSlide: View {
    @Binding var currentIndex: Int
    var routes: [Journey]?
    var errorMessage: String?
        
    var body: some View {
        ZStack {
          if errorMessage != nil {
                RouteErrorCard()
            } else if let routes {
                ZStack {
                    ForEach(Array(routes.enumerated()), id: \.element.id) { index, item in
                        let relativeIndex: CGFloat = CGFloat(index - currentIndex)
                        RouteCard(journey: item)
                            .frame(width: 300)
                            .padding(.horizontal, 30)
                            .offset(x: relativeIndex * 270)
                            .opacity(relativeIndex == 0 ? 1.0 : 0.3)
                            .scaleEffect(relativeIndex == 0 ? 1.0 : 0.9)
                            .zIndex(-abs(Double(relativeIndex)))
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
                ProgressView("경로를 찾는 중...")
            }
        }
    }
}
