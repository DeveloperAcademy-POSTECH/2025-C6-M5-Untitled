//
//  RouteCircle.swift
//  BusRoad
//
//  Created by 박난 on 10/14/25.
//
import SwiftUI

struct RouteCircle: View {
    var status: Status          // 활성, 비활성에 따라 색깔 변화
    var routeNode: RouteNode    // 버스, 도보 노드에 따라 아이콘 변화
    
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
    }
}

#Preview {
    RouteCircle(status: .active, routeNode: DummyData.busNode.asRouteNode)
}
