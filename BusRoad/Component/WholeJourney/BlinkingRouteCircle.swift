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
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                status.toggle()
            }
        }
    }
}

#Preview {
    BlinkingRouteCircle(routeNode: DummyData.busNode.asRouteNode)
}
