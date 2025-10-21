//
//  ToDestination.swift
//  BusRoad
//
//  Created by 강진 on 10/14/25.
//

import SwiftUI
import CoreLocation

struct ToDestination: View {
    @ObservedObject var vm = WalkingViewModel()
    
    var journey: Journey
    var index: Int
    let threshold: Double = 40  // 방향 허용 오차
    
    var body: some View {
        
        if case let .walk(node) = journey.nodes[index] {
            VStack(alignment: .leading) {
                Spacer()
                Text(node.end.name)
                    .font(.presemi36)
                    .foregroundColor(.primaryHeavy)
                Text(index == journey.nodes.count - 1 ? "목적지로 가야 해요." : "정류장으로 가야 해요.")
                    .font(.prereg36)
                    .foregroundColor(.primaryHeavy)
                Spacer()
                
                HStack {
                    Spacer()
                    VStack {
                        
                        ZStack{
                            
                            Circle()
                                .frame(width: 18, height: 18)
                                .foregroundColor(vm.arrowBearing > threshold && vm.arrowBearing < 360 - threshold ? .subStrong.opacity(0.5) : .subStrong)
                                .offset(y: -100)
                            
                            ArrowView(bearing: vm.arrowBearing, threshold: threshold)
                                .frame(width: 160, height: 160)
                                .padding(24)
                                .padding([.top], 8)
                        }
                        Button("도착 시뮬레이션 (remain = 5)") {
                            vm.arrived = true
                        }
                    }
                    Spacer()
                }
                
                Spacer()
                Text(vm.bigDistanceText)
                    .font(.presemi32)
                    .foregroundColor(.primaryHeavy)
                    .monospacedDigit()
                Text("남았어요.")
                    .font(.prereg32)
                    .foregroundColor(.primaryHeavy)
                    .padding(.bottom, 50)
            }
            .padding(.horizontal, 30)
            .onAppear {
                vm.setDestination(from: node)
            }
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36)
                .foregroundColor(.red)
        }
    }
}

struct ArrowView: View {
    let radius: CGFloat = 100
    let dotSize: CGFloat = 18
    let bearing: CLLocationDirection
    let threshold: Double   // 방향 허용 오차
    
    private var smoothAngle: Double {
        if bearing < threshold || bearing > 360.0 - threshold {
            return 0
        } else {
            return bearing < 180 ? bearing : bearing - 360
        }
    }
    private var angleDelta: Double {
        return abs(bearing < 180 ? bearing : bearing - 360)
    }
    
    var body: some View {
        ZStack {
            if angleDelta > threshold {
                ArcPath(relativeAngle: smoothAngle)
                    .stroke(Color.subStrong.opacity(0.2),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .frame(width: 2 * radius, height: 2 * radius)
            }
            
            Group {
                Image(systemName: "arrow.up")
                    .font(.system(size: 160, weight: .bold))
                    .foregroundColor(.primaryNormal)
                    .symbolRenderingMode(.hierarchical)
                
                if angleDelta > threshold {
                    Circle()
                        .frame(width: dotSize, height: dotSize)
                        .foregroundColor(.subStrong)
                        .offset(y: -radius)
                }
            }
            .rotationEffect(.degrees(smoothAngle))        // ← 보정된 값 적용
            .animation(.easeInOut(duration: 0.25), value: smoothAngle)
        }
    }
}
// TODO: -180도랑 180도 사이에서 한바퀴 도는 거 수정
// TODO: threshold에서 붙을 때 쫀득하게 붙게(animation 좀더 느리게)
// TODO: threhold 40도로 수정
// TODO: 도착 애니메이션 수정
// TODO: 도보 단계별 안내 전환할 때 수정


struct ArcPath: Shape {
    var relativeAngle: CLLocationDirection
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        let startAngle: Angle
        let endAngle: Angle
        if relativeAngle > 0 {
            startAngle = .degrees(10 - 90)
            endAngle = .degrees(relativeAngle - 10 - 90)
        } else {
            startAngle = .degrees(-10 - 90)
            endAngle = .degrees(relativeAngle + 10 - 90)
        }
        
        return Path { p in
            p.addArc(center: center,
                     radius: radius,
                     startAngle: startAngle,
                     endAngle: endAngle,
                     clockwise: relativeAngle < 0) // 각도가 음수이면 시계 반대 방향으로 회전
        }
    }
}
