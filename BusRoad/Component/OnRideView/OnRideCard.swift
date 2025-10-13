import SwiftUI

struct OnRideCard: View {
    
    let busStopName: String
    let remainingStops: Int
    let progress: CGFloat
    
    
    var body: some View {
        
        VStack {
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(busStopName)
                        .font(.prebold36)
                        .foregroundStyle(remainingStops == 1 ? .subLight : .primaryHeavy)
                    
                    Text("정류장에서 내려야 해요.")
                        .font(.prereg24)
                        .foregroundStyle(remainingStops == 1 ? .subLight : .primaryHeavy)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
            
            
            
            //TODO: 여기에 로티,이미지 파일 들어가야함
            /// 버스 탑승 중 이미지
            Rectangle()
                .cornerRadius(10)
                .foregroundStyle(.subPoint)
                .frame(width: 176, height: 146)
                .padding(.horizontal, 84)
                .padding(.top, 48)
                .padding(.bottom, 50)
            
            
            /// 남은 정류장 안내
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(remainingStops)정류장")
                        .font(.presemi20)
                        .foregroundStyle(remainingStops == 1 ? .subLight : .primaryHeavy)
                    
                    Text("남았어요")
                        .font(.prereg20)
                        .foregroundStyle(remainingStops == 1 ? .subLight : .primaryHeavy)
                }
            }
            .padding(.horizontal, 40)
            
            /// 남은정류장 progressbar
            BusStopProgress(
                progress: progress,
                trackColor: remainingStops == 1 ? Color(.subNormal) : Color(.primaryNormal),
                fillColor: remainingStops == 1 ? Color(.subHeavy): Color(.primaryDisable)
            )
            .padding(.horizontal, 40)
        }
        .padding(.top, 60)
        .padding(.bottom, 45)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(remainingStops == 1 ? .primaryStrong : .primaryLight))
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
            let progress = min(max(progress,0),1)
            
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
        remainingStops: 1,
        progress: 0.9
    )
}
