//
//  ToDestination.swift
//  BusRoad
//
//  Created by 강진 on 10/14/25.
//

import SwiftUI
import CoreLocation

struct ToDestination: View {
  @StateObject var vm = WalkingViewModel()
  
  var journey: Journey
  var index: Int
  
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
                .foregroundColor(vm.arrowBearing > 30 && vm.arrowBearing < 330 ? .subStrong.opacity(0.5) : .subStrong)
                .offset(y: -100)
              
              ArrowView(vm: vm, bearing: vm.arrowBearing)
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
        Text("앞에 있어요.")
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
  @ObservedObject var vm: WalkingViewModel
  let radius: CGFloat = 100 // Dot의 회전 반경 (offset(y: -100)과 일치)
  let dotSize: CGFloat = 18
  let bearing: CLLocationDirection
  
  var body: some View {
    ZStack {
      if vm.arrowBearing > 30 && vm.arrowBearing < 330 {
        ArcPath(relativeAngle: vm.arrowBearing) // 궤적을 그리는 Shape
          .stroke(Color.subStrong.opacity(0.2), style: StrokeStyle(lineWidth: 13, lineCap: .round))
          .frame(width: 2 * radius, height: 2 * radius) // ZStack 크기에 맞춰 중앙 정렬
      }
      Group{
        Image(systemName: "arrow.up")
          .font(.system(size: 160, weight: .bold))
          .aspectRatio(contentMode: .fit)
          .foregroundColor(.primaryNormal)
          .symbolRenderingMode(.hierarchical)
        if vm.arrowBearing > 30 && vm.arrowBearing < 330 {
          Circle()
            .frame(width: 18, height: 18)
            .foregroundColor(.subStrong)
            .offset(y: -100)
        }
      }
      .rotationEffect(.degrees(
        vm.arrowBearing >= 330 ? 360 :
          vm.arrowBearing <= 30 ? 0 :
          vm.arrowBearing
      ))
      .animation(.easeInOut(duration: 0.3), value: vm.arrowBearing)
    }
    
  }
}

struct ArcPath: Shape {
    var relativeAngle: CLLocationDirection // -180 ~ +180

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        let startAngle: Angle
        let endAngle: Angle
        if relativeAngle <= 180 {
            startAngle = .degrees(-80)
            endAngle = .degrees(-100 + relativeAngle)
        } else {
            startAngle = .degrees(-80 + relativeAngle)
            endAngle = .degrees(-100)
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
