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
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var journey: Journey
    var index: Int
    let threshold: Double = 40  // 방향 허용 오차
    
    var body: some View {
        
        if case let .walk(node) = journey.nodes[index] {
            VStack(alignment: .leading, spacing: 0) {
                Text(node.end.name)
                    .font(.presemi36Scaled)
                    .foregroundColor(.primaryHeavy)
                    .padding(.top, 25.wScaled)
                
                Text(index == journey.nodes.count - 1 ? "목적지로 가야 해요." : "정류장으로 가야 해요.")
                    .font(.prereg36Scaled)
                    .foregroundColor(.primaryHeavy)
                    .padding(.top, 12.wScaled)
                    .padding(.bottom, 70.wScaled)
                
                HStack {
                    Spacer()
                    ZStack{
                        Circle()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.subStrong.opacity(0.5))
                            .offset(y: -100)
                        
                        ArrowView(bearing: vm.arrowBearing, threshold: threshold)
                            .frame(width: 160, height: 160)
                            .padding(24.wScaled)
                    }
                    Spacer()
                }
                .padding(.bottom, 76.wScaled)
                
                Text(vm.bigDistanceText)
                    .font(.presemi32Scaled)
                    .foregroundColor(.primaryHeavy)
                    .monospacedDigit()
                    .padding(.bottom, 11.wScaled)
                
                Text("남았어요.")
                    .font(.prereg32Scaled)
                    .foregroundColor(.primaryHeavy)
                    .padding(.bottom, 36.wScaled)
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        coordinator.advanceJourneyStage()   // TODO: 나중에 상위뷰로 빼기
                    } label: {
                        Text("이미 목적지에 도착하셨나요?")
                            .font(.premed12Scaled)
                            .foregroundColor(.primaryHeavy)
                            .underline()
                            .padding(.bottom, 24.wScaled)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 32.wScaled)
            .onAppear {
                vm.setDestination(from: node)
            }
        } else {
            Text("경로 정보 확인 불가")
                .font(.presemi36Scaled)
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

