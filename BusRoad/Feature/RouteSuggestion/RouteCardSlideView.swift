//
//  RouteCardSlideView.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCardSlideView: View {
  @StateObject private var viewModel = BusRouteViewModel()
  @State private var currentIndex: Int = 0
  
  @Binding var centerRoute: BusRoute?
  
  var body: some View {
    ZStack {
      if viewModel.isLoading {
        ProgressView("경로를 찾는 중...")
      } else if let errorMessage = viewModel.errorMessage {
        VStack {
          Text("오류 발생")
            .font(.headline)
          Text(errorMessage)
            .font(.caption)
            .foregroundColor(.gray)
        }
      } else {
        GeometryReader { geometry in
          let cardWidth = geometry.size.width * 0.8
          let cardSpacing = cardWidth * 0.9
          
          ZStack {
            ForEach(viewModel.routes.indices, id: \.self) { index in
              let relativeIndex = index - currentIndex
              
              RouteCardView(route: viewModel.routes[index],
                            isFirstCard: index == 0)
              .frame(width: cardWidth)
              .offset(x: CGFloat(relativeIndex) * cardSpacing)
              .opacity(relativeIndex == 0 ? 1.0 : 0.5)
              .scaleEffect(relativeIndex == 0 ? 1.0 : 0.9)
              .zIndex(-abs(Double(relativeIndex)))
            }
          }
          .frame(width: geometry.size.width, height: geometry.size.height)
          .gesture(
            DragGesture()
              .onEnded { value in
                if abs(value.translation.width) < 50 {
                  return
                }
                if value.translation.width > 0 {
                  currentIndex = max(0, currentIndex - 1)
                }
                else {
                  currentIndex = min(viewModel.routes.count - 1, currentIndex + 1)
                }
              }
          )
          .animation(.spring(), value: currentIndex)
        }
      }
    }
    .onAppear {
      viewModel.fetchRoute()
    }
    .onChange(of: viewModel.routes) { oldRoutes, newRoutes in
      if !newRoutes.isEmpty {
        centerRoute = newRoutes[0]
      }
    }
    .onChange(of: currentIndex) { oldIndex, newIndex in
      if !viewModel.routes.isEmpty && viewModel.routes.indices.contains(newIndex) {
        centerRoute = viewModel.routes[newIndex]
      }
    }
  }
}

#Preview {
  RouteCardSlideView(centerRoute: .constant(nil))
}
