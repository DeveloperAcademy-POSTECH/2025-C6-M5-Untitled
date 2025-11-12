import SwiftUI
import Lottie

struct OnRideCard: View {
    
    let busStopName: String
    let canAlight: Bool
    let progress: CGFloat
    let remainingStations: Int
    let hasArrived: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(canAlight ? Color.primaryStrong : Color.primarywhite)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
            
            VStack(spacing: 40.wScaled) {
                
                VStack(spacing: 40.wScaled) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8.wScaled) {
                            Text("하차 정류장")
                                .font(.prereg24Scaled)
                                .foregroundStyle(canAlight ? .subLight : .primaryHeavy)
                            
                            MarqueeText(
                                text: busStopName,
                                font: .presemi36Scaled,
                                uiFont: .presemi36Scaled,
                                startDelay: 1.0,
                                alignment: .leading
                            )
                            .foregroundStyle(canAlight ? .subLight : .primaryHeavy)
                            
                            
                        }
                        
                        Spacer()
                    }
                    
                    charAnimation
                        .frame(height: 200.wScaled)
                        .padding(.leading, 15.wScaled)
                }
                
                VStack(spacing: 11 .wScaled) {
                    HStack {
                        if canAlight {
                            Text("이번 정류장에서 내리세요.")
                                .font(.presemi20Scaled)
                                .foregroundStyle(canAlight ? .subNormal : .primaryStrong)
                        } else {
                            Text("\(remainingStations)정류장 ")
                                .font(.presemi20Scaled)
                                .foregroundStyle(canAlight ? .subNormal : .primaryStrong) +
                            Text("남았어요")
                                .font(.prereg20Scaled)
                                .foregroundStyle(canAlight ? .subNormal : .primaryStrong)
                        }
                        
                        Spacer()
                    }
                    
                    BusStopProgress(
                        progress: progress,
                        trackColor: canAlight ? Color(.subHeavy) : Color(.primaryDisable),
                        fillColor: canAlight ? Color(.subNormal): Color(.primaryNormal)
                    )
                }
            }
            .padding(.horizontal, 40.wScaled)
        }
    }
    
    // MARK: - 캐릭터 애니메이션
    private var charAnimation: some View {
        ZStack(alignment: .topLeading, content: {
            // 배경 애니메이션 (tree.json)
            LottieView(animation: .named("tree"))
                .playing(loopMode: .loop)
                .animationSpeed(1.0)
                .frame(width: 127.wScaled, height: 110.wScaled)
                .border(canAlight ? .primarywhite : Color.primaryStrong, width: 2)
                .padding(.top, canAlight ? 12.wScaled : 0)
            
            // 메인 애니메이션 (조건에 따라 변경)
            LottieView(animation: .named(canAlight ? "Yellow" : "OnRiding"))
                .playing(loopMode: .loop)
                .animationSpeed(1.0)
                .frame(height: canAlight ? 222.wScaled : 200.wScaled)
                .padding(.leading, canAlight ? 30.wScaled : -20.wScaled)
        }
        )
      
    }
    
}

// MARK: - Progressbar

struct BusStopProgress: View {
    
    let progress: CGFloat
    var trackColor: Color = .subNormal
    var fillColor: Color = .subHeavy
    
    var body: some View {
        
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = min(max(progress, 0), 1)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: width, height: 8)
                    .cornerRadius(10)
                    .foregroundStyle(trackColor)
                
                Rectangle()
                    .frame(width: progress*width, height: 8)
                    .foregroundStyle(fillColor)
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: 10,
                                bottomLeading: 10,
                                bottomTrailing: progress >= 1 ? 10 : 0,
                                topTrailing: progress >= 1 ? 10 : 0
                            )
                        )
                    )
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 프리뷰

#Preview("하차 가능 - 3정류장 남음") {
    OnRideCard(
        busStopName: "강남역 9번 출구",
        canAlight: true,
        progress: 0.7,
        remainingStations: 3,
        hasArrived: false
    )
    .padding()
}

#Preview("하차 불가 - 5정류장 남음") {
    OnRideCard(
        busStopName: "서울역 12번 출구 앞",
        canAlight: false,
        progress: 0.4,
        remainingStations: 5,
        hasArrived: false
    )
    .padding()
}

#Preview("도착 완료") {
    OnRideCard(
        busStopName: "역삼역 2번 출구",
        canAlight: true,
        progress: 1.0,
        remainingStations: 0,
        hasArrived: true
    )
    .padding()
}

#Preview("시작 - 10정류장 남음") {
    OnRideCard(
        busStopName: "포항시청 앞 정류장",
        canAlight: false,
        progress: 0.1,
        remainingStations: 10,
        hasArrived: false
    )
    .padding()
}

#Preview("긴 이름 정류장") {
    OnRideCard(
        busStopName: "포항공과대학교 제2학생회관 앞 정류장",
        canAlight: true,
        progress: 0.85,
        remainingStations: 1,
        hasArrived: false
    )
    .padding()
}
