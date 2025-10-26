//
//  BlinkingRouteCircle.swift
//  BusRoad
//
//  Created by 박난 on 10/15/25.
//
import Combine
import SwiftUI

struct BlinkingRouteCircle: View {
    @State var status: Status = .active
    var routeNode: RouteNode    // 버스, 도보 노드에 따라 아이콘 변화
    
    var activeToDisableDuration: Double = 0.6
    var disableToActiveDuration: Double = 0.8
    var activeHoldDuration: Double = 0.3
    
    var iconName: String {
        switch routeNode {
        case .bus:
            return "bus.fill"
        case .walk:
            return "figure.walk"
        }
    }
    var iconColor: Color {
        switch status {
        case .active:
            return .subLight
        case .disable:
            return .greyNormal
        }
    }
    var circleColor: Color {
        switch status {
        case .active:
            return .primaryStrong
        case .disable:
            return .primaryLight
        }
    }

    var body: some View {
        ZStack{
          Circle()
            .frame(width: 36, height:36)
            .foregroundColor(circleColor)
          Image(systemName: iconName)
            .font(.system(size: 18))
            .foregroundColor(iconColor)
        }
        .onAppear {
            startBlinkingLoop()
        }
    }
}

private extension BlinkingRouteCircle {
    
    
    func startBlinkingLoop() {
        changeToActive()
    }
    
    func changeToActive() {
        withAnimation(.easeInOut(duration: disableToActiveDuration)) {
            status = .active
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + disableToActiveDuration + activeHoldDuration) {
            changeToDisable()
        }
    }
    
    func changeToDisable() {
        withAnimation(.easeInOut(duration: activeToDisableDuration)) {
            status = .disable
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + activeToDisableDuration) {
            changeToActive()
        }
    }
}


//#Preview {
//    BlinkingRouteCircle(routeNode: DummyData.busNode.asRouteNode)
//}
