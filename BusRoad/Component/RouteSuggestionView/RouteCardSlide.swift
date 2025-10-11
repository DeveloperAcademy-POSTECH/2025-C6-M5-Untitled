//
//  RouteCardSlide.swift
//  C6test
//
//  Created by 강진 on 9/25/25.
//

import SwiftUI

struct RouteCardSlide: View {
    //  @ObservedObject var viewModel: BusRouteViewModel    // viewModel은 컴포넌트와 직접적으로 연결되지 않도록 함
    @Binding var currentIndex: Int
    var routes: [Journey]?
    var errorMessage: String?
    
    //  @Binding var centerRoute: BusRoute?
    
    var body: some View {
        ZStack {
            if let errorMessage {
                VStack {
                    Text("오류 발생")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if let routes {  // TODO: Geometry 쓰지 말고 padding으로 바꾸기(Hi-fi 참고)
                GeometryReader { geometry in
                    let cardWidth = geometry.size.width * 0.8
                    let cardSpacing = cardWidth * 0.9
                    
                    ZStack {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, item in
                            let relativeIndex: CGFloat = CGFloat(index - currentIndex)
                            
                            RouteCard(journey: item, isFirstCard: index==0)
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
                                    // 오른쪽 스와이프 -> 이전 카드
                                    currentIndex = max(0, currentIndex - 1)
                                } else {
                                    // 왼쪽 스와이프 -> 다음 카드
                                    currentIndex = min(routes.count - 1, currentIndex + 1)
                                }
                            }
                    )
                }
                .animation(.spring(), value: currentIndex)
            } else {
                ProgressView("경로를 찾는 중...")
            }
        }
    }
}

//#Preview {
//    RouteCardSlide()
//}
