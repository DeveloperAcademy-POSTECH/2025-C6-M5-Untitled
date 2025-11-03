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
            VStack {
                Spacer(minLength: 20)
                HStack{
                    Image(RouteStage(rawValue: context.state.stage)?.image ?? "questionmark")
                        .resizable()
                        .frame(width: 42, height: 42)
                    VStack(alignment:.leading){
                        Text(ProgressLiveActivityManager.description(for: context.state.stage, destination: context.state.destination))
                            .font(.presemi18)
                            .foregroundColor(.primaryblack)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Text(
                            ProgressLiveActivityManager.subDescription(
                                for: context.state.stage,
                                leftDistance: context.state.leftDistance ?? context.state.totalDistance,
                                remainingBusStops: context.state.remainingBusStops,
                                busTravelTime: context.state.busTravelTime
                            )
                        )
                            .font(.premed12)
                            .foregroundColor(.greyDisable)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .frame(maxWidth: .infinity, maxHeight: 57, alignment: .leading)
                ProgressBarWithTracker(
                    progressValue: context.state.maxProgressValue,
                    imageName: RouteStage(rawValue: context.state.stage)?.image ?? "questionmark")
                .padding(30)
                Spacer(minLength: 20)
            }
            .frame(width: 360, height: 145)
            .activitySystemActionForegroundColor(Color.black)
            
        } dynamicIsland: { context in
            // Dynamic Island View
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
//                    Text(ProgressLiveActivityManager.description(for: context.state.stage, destination: context.state.destination))
                }
                DynamicIslandExpandedRegion(.trailing) {
//                    let progress = ProgressLiveActivityManager.progress(
//                        for: context.state.stage,
//                        totalDistance: context.state.totalDistance,
//                        leftDistance: context.state.leftDistance ?? context.state.totalDistance,
//                        busProgess: context.state.busProgress,
//                        remainingBusStops: context.state.remainingBusStops
//                    )
//                    Text("\(Int(progress * 100))%")
                }
                DynamicIslandExpandedRegion(.bottom) {
//                    Text("경로를 따라 이동하세요.")
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
    
    private let iconSize: CGFloat = 20
    private let barHeight: CGFloat = 10
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            GeometryReader { geometry in
                
                let totalWidth = geometry.size.width
                
                // 1. 프로그레스 바 배경 (회색)
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: barHeight)
                
                // 2. 프로그레스 바 채우기
                Capsule()
                    .fill(Color.primaryNormal)
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
                                        leftDistance: 35, totalDistance: 70, destination: "포스텍", subDescription: "약 3분 정도 걸려요", maxProgressValue: 0, currentProgressValue: 0, busProgress: 0, remainingBusStops: 10, busTravelTime: 0)
    }
    
    fileprivate static var onBus: ProgressAttributes.ContentState {
        ProgressAttributes.ContentState(stage: RouteStage.onBus.rawValue, leftDistance: 30, totalDistance: 50, destination: "포항역", subDescription: "2정류장 남았어요", maxProgressValue: 30, currentProgressValue: 30, busProgress: 0.5, remainingBusStops: 2, busTravelTime: 27)
    }
}

// ⭐️ 파일 스코프 (전역)에서 선언
#Preview("Notification", as: .content, using: ProgressAttributes.preview) {
    ProgressLiveActivity()
} contentStates: {
    ProgressAttributes.ContentState.walking
    ProgressAttributes.ContentState.onBus
}
