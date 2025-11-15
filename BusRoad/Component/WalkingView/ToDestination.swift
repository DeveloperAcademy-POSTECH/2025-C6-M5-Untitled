//
//  ToDestination.swift
//  BusRoad
//
//  Created by 강진 on 10/14/25.
//

import SwiftUI
import CoreLocation

struct ToDestination: View {
    @ObservedObject var vm: WalkingViewModel  // 파라미터로 받기
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var journey: Journey
    var index: Int
    let threshold: Double = 30  // 방향 허용 오차
    
    var body: some View {
        
        if case let .walk(node) = journey.nodes[index] {
            VStack(spacing: 60) {
                
                VStack(spacing: 8) {
                    Text(index == journey.nodes.count - 1 ? "목적지까지 걷기" : "정류장까지 걷기")
                        .font(.prereg20)
                        .foregroundColor(.primaryHeavy)
                    
                    MarqueeText(
                        text: node.end.name,
                        font: .presemi36Scaled,
                        uiFont: .presemi36Scaled,
                        startDelay: 1.0,
                        alignment: .center
                    )
                    .foregroundColor(.primaryHeavy)
                }
                
                HStack {
                    Spacer()
                    ZStack{
                        Circle()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.subPoint.opacity(0.5))
                            .offset(y: -100)
                        
                        ArrowView(bearing: vm.arrowBearing, threshold: threshold)
                            .frame(width: 160, height: 160)
                            .padding(24.wScaled)
                    }
                    Spacer()
                }
                .padding(.bottom, 30.wScaled)
                
                
                HStack {
                    Text(vm.bigDistanceText)
                        .font(.presemi32Scaled)
                        .foregroundColor(.primaryHeavy)
                        .monospacedDigit()
                    
                    Text("남았어요.")
                        .font(.prereg32Scaled)
                        .foregroundColor(.primaryHeavy)
                }
            }
            .padding(.horizontal, 32.wScaled)
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
    let threshold: Double
    let base: Double = -90
    let pad: Double = 15
    
    @State private var smoothAngle: Double = 0
    @State private var inDeadzone: Bool = true
    @State private var arcAngle: Double = 0  // normalized 각도로 유지
    
    private var enterDeadzoneThreshold: Double { threshold }
    private var exitDeadzoneThreshold: Double { threshold + 5 }
    
    private var currentBearing: Double {
        bearing < 180 ? bearing : bearing - 360
    }
    
    // Arc Opacity: 정면 근처에서만 사라짐
    private var arcOpacity: Double {
        let fadeStartAngle = 25.0
        let fadeEndAngle = 10.0
        
        let absAngle = abs(arcAngle)
        
        if absAngle <= fadeEndAngle {
            return 0.0
        } else if absAngle >= fadeStartAngle {
            return 1.0
        } else {
            return (absAngle - fadeEndAngle) / (fadeStartAngle - fadeEndAngle)
        }
    }
    
    // Dynamic Pad
    private func getDynamicPad() -> Double {
        let absAngle = abs(arcAngle)
        
        if absAngle < 12 {
            return 0
        } else if absAngle < 25 {
            return pad * (absAngle - 12) / 13
        } else {
            return pad
        }
    }
    
    // Arc Start/End Angle
    private var arcStartAngle: Double {
        let dynamicPad = getDynamicPad()
        
        if arcAngle > 0 {
            return base + dynamicPad
        } else if arcAngle < 0 {
            return base - dynamicPad
        } else {
            return base
        }
    }
    
    private var arcEndAngle: Double {
        let dynamicPad = getDynamicPad()
        
        if arcAngle > 0 {
            return base + arcAngle - dynamicPad
        } else if arcAngle < 0 {
            return base + arcAngle + dynamicPad
        } else {
            return base
        }
    }
    
    var body: some View {
        ZStack {
            if abs(arcAngle) > 0.5 {
                ArcPath(
                    startAngle: arcStartAngle,
                    endAngle: arcEndAngle
                )
                .stroke(
                    Color.subPoint.opacity(0.2),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .frame(width: 2 * radius, height: 2 * radius)
                .opacity(arcOpacity)
            }
            
            // 화살표 + 점
            Group {
                Image(systemName: "arrow.up")
                    .font(.system(size: 160, weight: .bold))
                    .foregroundColor(.primaryNormal)
                    .symbolRenderingMode(.hierarchical)
                
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .foregroundColor(.subPoint)
                    .offset(y: -radius)
            }
            .rotationEffect(.degrees(smoothAngle))
        }
        .onChange(of: bearing) { _, newValue in
            updateValues(newValue)
        }
        .onAppear {
            smoothAngle = currentBearing
            arcAngle = currentBearing
            inDeadzone = abs(currentBearing) <= enterDeadzoneThreshold
        }
    }
    
    // Deadzone + 부드러운 회전 처리
    private func updateValues(_ newValue: CLLocationDirection) {
        let newBearing = newValue < 180 ? newValue : newValue - 360
        
        let nowInDeadzone: Bool
        if inDeadzone {
            nowInDeadzone = abs(newBearing) <= exitDeadzoneThreshold
        } else {
            nowInDeadzone = abs(newBearing) <= enterDeadzoneThreshold
        }
        
        var targetAngle: Double
        
        if nowInDeadzone {
            let currentNormalized = smoothAngle.truncatingRemainder(dividingBy: 360)
            var normalizedSigned = currentNormalized
            
            if normalizedSigned > 180 {
                normalizedSigned -= 360
            } else if normalizedSigned < -180 {
                normalizedSigned += 360
            }
            
            targetAngle = smoothAngle - normalizedSigned
            
        } else {
            let currentNormalized = smoothAngle.truncatingRemainder(dividingBy: 360)
            let diff = newBearing - currentNormalized
            
            var shortestDiff = diff
            if diff > 180 {
                shortestDiff = diff - 360
            } else if diff < -180 {
                shortestDiff = diff + 360
            }
            
            targetAngle = smoothAngle + shortestDiff
        }
        
        // arcAngle 계산: 최단 경로로 이동
        var targetArcAngle: Double
        if nowInDeadzone {
            targetArcAngle = 0
        } else {
            // 현재 arcAngle에서 가장 가까운 경로로 newBearing까지 이동
            var normalized = newBearing
            let currentArc = arcAngle
            
            // 최단 거리 계산
            let diff = normalized - currentArc
            if diff > 180 {
                normalized -= 360
            } else if diff < -180 {
                normalized += 360
            }
            
            targetArcAngle = normalized
        }
        
        let animationDuration: Double = 0.4
        
        if nowInDeadzone {
            withAnimation(.easeOut(duration: animationDuration)) {
                smoothAngle = targetAngle
                arcAngle = targetArcAngle
                inDeadzone = nowInDeadzone
            }
        } else if inDeadzone {
            withAnimation(.easeIn(duration: animationDuration)) {
                smoothAngle = targetAngle
                arcAngle = targetArcAngle
                inDeadzone = nowInDeadzone
            }
        } else {
            withAnimation(.easeInOut(duration: animationDuration)) {
                smoothAngle = targetAngle
                arcAngle = targetArcAngle
                inDeadzone = nowInDeadzone
            }
        }
    }
}

struct ArcPath: Shape {
    var startAngle: Double
    var endAngle: Double
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        
        return Path { p in
            p.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(endAngle),
                clockwise: startAngle > endAngle 
            )
        }
    }
}
