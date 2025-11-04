import ActivityKit
import WidgetKit
import SwiftUI


struct ProgressAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stage: String
        var leftDistance: Double
        var totalDistance: Double
        var destination: String
        var subDescription: String
        var maxProgressValue: Double
        var currentProgressValue: Double
        var busProgress: Double
        var remainingBusStops: Int
        var busTravelTime: Int
    }
}

struct ProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProgressAttributes.self) { context in
            // 잠금화면 영역 (Lock Screen View)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 9){
                    Image(RouteStage(rawValue: context.state.stage)?.image ?? "QuestionMark")
                        .resizable()
                        .frame(width: 42, height: 42)
                    VStack(alignment:.leading, spacing: 3){
                        Text(ProgressLiveActivityManager.description(for: context.state.stage, destination: context.state.destination))
                            .font(.presemi18)
                            .foregroundColor(.liveTitle)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(
                            ProgressLiveActivityManager.subDescription(
                                for: context.state.stage,
                                leftDistance: context.state.leftDistance ?? context.state.totalDistance,
                                remainingBusStops: context.state.remainingBusStops,
                                busTravelTime: context.state.busTravelTime
                            )
                        )
                            .font(.premed12)
                            .foregroundColor(.liveSubtitle)
                    }
//                    .frame(height: 60)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity,  alignment: .leading)
                ProgressBarWithTracker(
                    progressValue: context.state.maxProgressValue,
                    imageName: RouteStage(rawValue: context.state.stage)?.image ?? "questionmark")
                .padding(.horizontal, 30)
                .padding(.top, 21)
            }
            .padding(.vertical, 30)
            .activityBackgroundTint(Color.liveBackground)
        } dynamicIsland: { context in
            // Dynamic Island View
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {

                }
                DynamicIslandExpandedRegion(.trailing) {

                }
                DynamicIslandExpandedRegion(.bottom) {

                }
            } compactLeading: {
                HStack{
                    Image(RouteStage(rawValue: context.state.stage)?.minimalImage ?? "BusIcon")
                        .padding(.trailing, 5)
                }
            } compactTrailing: {
            } minimal: {
                Image(RouteStage(rawValue: context.state.stage)?.minimalImage ?? "BusIcon")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

struct ProgressBarWithTracker: View {
    let progressValue: Double
    let imageName: String
    
    private let iconSize: CGFloat = 22
    private let barHeight: CGFloat = 10
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            GeometryReader { geometry in
                
                let totalWidth = geometry.size.width
                
                // 1. 프로그레스 바 배경 (회색)
                Capsule()
                    .fill(Color.liveLine)
                    .frame(height: barHeight)
                
                // 2. 프로그레스 바 채우기
                Capsule()
                    .fill(Color.livePoint)
                    .frame(width: totalWidth * progressValue, height: barHeight)
                
                // 3. 진행률 추적 아이콘 (움직이는 부분)
                Image(imageName)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .offset(x: calculateIconOffset(totalWidth: totalWidth))
                    .position(x: 0, y: barHeight / 2)
            }
        }
    }
    
    func calculateIconOffset(totalWidth: CGFloat) -> CGFloat {
        let maxOffset = totalWidth * progressValue
        
        // 아이콘 폭의 절반
        let iconHalfWidth = iconSize / 2
        // 아이콘의 중앙이 현재 진행률 위치에 오도록 오프셋 조정
        let adjustedOffset = maxOffset - iconHalfWidth
        
        return max(iconHalfWidth, min(adjustedOffset + iconHalfWidth, totalWidth - iconHalfWidth))
    }
}

extension ProgressAttributes {
    fileprivate static var preview: ProgressAttributes {
        ProgressAttributes()
    }
}

extension ProgressAttributes.ContentState {
    fileprivate static var walking: ProgressAttributes.ContentState {
        ProgressAttributes.ContentState(stage: RouteStage.walkingToBus.rawValue,
                                        leftDistance: 35, totalDistance: 70, destination: "띄어쓰기가 어떻게 되는지 알아보기 위한 아무렇게나 넣는 목적지 입니다.", subDescription: "약 3분 정도 걸려요", maxProgressValue: 0, currentProgressValue: 0, busProgress: 0, remainingBusStops: 10, busTravelTime: 0)
    }
    
    fileprivate static var onBus: ProgressAttributes.ContentState {
        ProgressAttributes.ContentState(stage: RouteStage.onBus.rawValue, leftDistance: 30, totalDistance: 50, destination: "포항역", subDescription: "2정류장 남았어요", maxProgressValue: 0.5, currentProgressValue: 0.5, busProgress: 0.5, remainingBusStops: 2, busTravelTime: 27)
    }
}

// ⭐️ 파일 스코프 (전역)에서 선언
#Preview("Notification", as: .content, using: ProgressAttributes.preview) {
    ProgressLiveActivity()
} contentStates: {
    ProgressAttributes.ContentState.walking
    ProgressAttributes.ContentState.onBus
}
