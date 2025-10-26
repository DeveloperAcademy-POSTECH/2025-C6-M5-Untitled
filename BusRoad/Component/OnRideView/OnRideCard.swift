import SwiftUI
import Lottie

struct OnRideCard: View {
    
    let busStopName: String
    let canAlight: Bool
    let progress: CGFloat
    
    var body: some View {
        ZStack {
            
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(canAlight ? .primaryStrong : .primaryLight)
            
            VStack(spacing: 5.wScaled) {
                
                VStack(spacing: 48.wScaled) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8.wScaled) {
                            MarqueeText(
                                text: busStopName,
                                font: .presemi32Scaled,
                                uiFont: .presemi32Scaled,
                                startDelay: 1.0,
                                alignment: .leading
                            )
                            .foregroundStyle(canAlight ? .subLight : .primaryHeavy)
                            
                            Text("정류장에서 내려야 해요.")
                                .font(.prereg24Scaled)
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
                        Spacer()
                        
                        Text(canAlight ? "곧 내려야 해요" : " ")
                            .font(.presemi20Scaled)
                            .foregroundStyle(canAlight ? .subLight : .primaryHeavy)
                    }
                    
                    BusStopProgress(
                        progress: progress,
                        trackColor: canAlight ? Color(.subNormal) : Color(.primaryNormal),
                        fillColor: canAlight ? Color(.subHeavy): Color(.primaryDisable)
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
        })
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

#Preview {
    OnRideCard(
        busStopName: "Bus stop name",
        canAlight: false,
        progress: 0.9
    )
}
