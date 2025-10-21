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
                                .foregroundColor(.subStrong.opacity(0.5))
                                .offset(y: -100)
                            
                            ArrowView(bearing: vm.arrowBearing, threshold: threshold)
                                .frame(width: 160, height: 160)
                                .padding(24)
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
    let base: Double = -90
    let pad: Double = 10
    
    @State private var smoothAngle: Double = 0
    @State private var inDeadzone: Bool = true   // 현재 데드존(±threshold) 안인가?
    
    private var signedBearing: Double { bearing < 180 ? bearing : bearing - 360 } // -180..+180
    private var angleDelta: Double { abs(signedBearing) }
    
    private var startAngle: Double {
        if signedBearing > 0 {
            return base + pad
        } else {
            return base - pad
        }
    }
    private var endAngle: Double   {
        if signedBearing > 0 {
            return max(startAngle, base + smoothAngle - pad)
        } else {
            return min(startAngle, base + smoothAngle + pad)
        }
    }
    
    var body: some View {
        ZStack {
            if startAngle != endAngle {
                ArcPath(startAngle: startAngle, endAngle: endAngle)
                    .stroke(Color.subStrong.opacity(0.2),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .frame(width: 2 * radius, height: 2 * radius)
            }
            
            Group {
                Image(systemName: "arrow.up")
                    .font(.system(size: 160, weight: .bold))
                    .foregroundColor(.primaryNormal)
                    .symbolRenderingMode(.hierarchical)
                
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .foregroundColor(.subStrong)
                    .offset(y: -radius)
            }
            .rotationEffect(.degrees(smoothAngle))
        }
        .onChange(of: bearing) { _, newValue in
            updateValues(newValue)
        }
        .onAppear {
            updateValues(bearing) // 첫 렌더 시 상태 맞추기
        }
    }
    
    private func updateValues(_ newValue: CLLocationDirection) {
        let newSigned = newValue < 180 ? newValue : newValue - 360
        let nowInDeadzone = abs(newSigned) <= threshold
        
        switch (inDeadzone, nowInDeadzone) {
        case (true, false):
            // 데드존 → 바깥: "나가기" 순간
            withAnimation(.easeInOut(duration: 0.25)) {
                smoothAngle = newSigned
            }
            
        case (false, true):
            // 바깥 → 데드존: "들어오기" 순간
            withAnimation(.easeOut(duration: 1.0)) {
                smoothAngle = 0
            }
            // 즉시 붙이고 싶다면 위 withAnimation 대신: smoothAngle = 0
            
        case (false, false):
            // 바깥에서 계속 바깥: 즉시 업데이트
            smoothAngle = newSigned
            
        case (true, true):
            // 계속 데드존: 0 고정
            smoothAngle = 0
        }
        
        inDeadzone = nowInDeadzone
    }
}


// TODO: threshold에서 붙을 때 쫀득하게 붙게(animation 좀더 느리게)
// TODO: threhold 40도로 수정
// TODO: 도착 애니메이션 수정
// TODO: 도보 단계별 안내 전환할 때 수정
// TODO: 이미 목적지 도착하셨나요? 버튼 추가
// TODO: splashview에서 requestOrigin하도록 변경

struct ArcPath: Shape {
    var startAngle: Double  // degrees
    var endAngle: Double    // degrees
    
    var animatableData: Double {
        get { endAngle }
        set { endAngle = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        return Path { p in
            p.addArc(center: center,
                     radius: radius,
                     startAngle: .degrees(startAngle),
                     endAngle:   .degrees(endAngle),
                     clockwise: endAngle < startAngle)
        }
    }
}

