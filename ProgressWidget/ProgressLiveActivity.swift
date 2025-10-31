import ActivityKit
import WidgetKit
import SwiftUI


struct ProgressAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stage: String
        var leftDistance: Double?
        var totalDistance: Double
    }
}

struct ProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProgressAttributes.self) { context in
            // 잠금화면 영역 (Lock Screen View)
            VStack {
                Spacer(minLength: 8)
                HStack{
                    ZStack{
                        Circle()
                            .foregroundColor(.primaryNormal)
                            .frame(width: 42, height: 42)
                        Image(systemName: RouteStage(rawValue: context.state.stage)?.image ?? "questionmark")
                            .foregroundColor(.white)
                    }
                    VStack(alignment:.leading){
                        Text(RouteStage(rawValue: context.state.stage)?.description ?? "이동 중")
                            .font(.presemi18)
                            .foregroundColor(.primaryblack)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Text(RouteStage(rawValue: context.state.stage)?.subDescription ?? "경로 설명 중")
                            .font(.premed12)
                            .foregroundColor(.greyDisable)
                    }
                }
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity, maxHeight: 57, alignment: .leading)
                Text("전체 거리: \(String(format: "%.1f", context.state.totalDistance))m")
                    .font(.headline)
                Text("남은 거리: \(String(format: "%.1f", context.state.leftDistance ?? 0))m")
                    .font(.headline)
                
                ProgressView(value: ProgressLiveActivityManager.progress(
                    for: context.state.stage,
                    totalDistance: context.state.totalDistance,
                    leftDistance: context.state.leftDistance ?? context.state.totalDistance
                ),
                total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.primaryNormal)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Spacer(minLength: 8)
            }
            .frame(width: 360, height: 170)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            // Dynamic Island View
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(RouteStage(rawValue: context.state.stage)?.description ?? "안내 시작")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let progress = ProgressLiveActivityManager.progress(
                        for: context.state.stage,
                        totalDistance: context.state.totalDistance,
                        leftDistance: context.state.leftDistance ?? context.state.totalDistance
                    )
                    Text("\(Int(progress * 100))%")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("경로를 따라 이동하세요.")
                }
            } compactLeading: {
                HStack{
                    Image("BusIcon")
                        .padding(.trailing, 5)
                }
            } compactTrailing: {
            } minimal: {
                Image("BusIcon")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

// ⭐️ 파일 스코프 (전역)에서 선언
extension ProgressAttributes {
    fileprivate static var preview: ProgressAttributes {
        ProgressAttributes()
    }
}

// ⭐️ 파일 스코프 (전역)에서 선언
extension ProgressAttributes.ContentState {
    fileprivate static var walking: ProgressAttributes.ContentState {
        ProgressAttributes.ContentState(stage: RouteStage.atDestination.rawValue,
            leftDistance: 35, totalDistance: 70)
    }

    fileprivate static var onBus: ProgressAttributes.ContentState {
        ProgressAttributes.ContentState(stage: RouteStage.onBus.rawValue, totalDistance: 50)
    }
}

// ⭐️ 파일 스코프 (전역)에서 선언
#Preview("Notification", as: .content, using: ProgressAttributes.preview) {
   ProgressLiveActivity()
} contentStates: {
    ProgressAttributes.ContentState.walking
    ProgressAttributes.ContentState.onBus
}
