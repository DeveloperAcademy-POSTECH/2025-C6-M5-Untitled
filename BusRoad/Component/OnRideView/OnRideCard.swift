import SwiftUI

struct OnRideCard: View {
    
    let busStopName: String
    let canAlight: Bool
    let progress: CGFloat
    
    var body: some View {
        
        ZStack {
            
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(canAlight ? .primaryStrong : .primaryLight)
            
            VStack(spacing: 50.wScaled) {
                
                VStack(spacing: 48.wScaled) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8.wScaled) {
                            Text(busStopName)
                                .font(.prebold36Scaled)
                                .foregroundStyle(canAlight ? .subLight : .primaryHeavy)
                            
                            Text("정류장에서 내려야 해요.")
                                .font(.prereg24Scaled)
                                .foregroundStyle(canAlight ? .subLight : .primaryHeavy)
                        }
                        
                        Spacer()
                    }
                    
                    Rectangle()
                        .cornerRadius(10)
                        .foregroundStyle(.subPoint)
                        .frame(width: 176.wScaled, height: 146.wScaled)
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
        canAlight: true,
        progress: 0.9
    )
}
