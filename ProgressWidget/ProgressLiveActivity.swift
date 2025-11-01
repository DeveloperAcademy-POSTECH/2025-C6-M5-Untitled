import ActivityKit
import WidgetKit
import SwiftUI


struct ProgressAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stage: String
        var leftDistance: Double?
        var totalDistance: Double
        var destination: String
        var subDescription: String
        var maxProgressValue: Double
        var currentProgressValue: Double
        var totalBusStops: Int
        var remainingBusStops: Int
    }
}

struct ProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProgressAttributes.self) { context in
            // 잠금화면 영역 (Lock Screen View)
            VStack {
                Spacer(minLength: 8)
                HStack{
                    Image(RouteStage(rawValue: context.state.stage)?.image ?? "questionmark")
                        .resizable()
                        .frame(width: 42, height: 42)
                        .foregroundColor(.white)
                    VStack(alignment:.leading){
                        Text(ProgressLiveActivityManager.description(for: context.state.stage, destination: context.state.destination))
                        .font(.presemi18)
                            .foregroundColor(.primaryblack)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Text(ProgressLiveActivityManager.subDescription(for: context.state.stage, leftDistance: context.state.leftDistance ?? context.state.totalDistance))
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
                
                ProgressView(value: context.state.maxProgressValue,
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
                    Text(ProgressLiveActivityManager.description(for: context.state.stage, destination: context.state.destination))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let progress = ProgressLiveActivityManager.progress(
                        for: context.state.stage,
                        totalDistance: context.state.totalDistance,
                        leftDistance: context.state.leftDistance ?? context.state.totalDistance,
                        totalBusStops: context.state.totalBusStops,
                        remainingBusStops: context.state.remainingBusStops
                    )
                    Text("\(Int(progress * 100))%")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("경로를 따라 이동하세요.")
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

// ⭐️ 파일 스코프 (전역)에서 선언
extension ProgressAttributes {
    fileprivate static var preview: ProgressAttributes {
        ProgressAttributes()
    }
}

// ⭐️ 파일 스코프 (전역)에서 선언
extension ProgressAttributes.ContentState {
    fileprivate static var walking: ProgressAttributes.ContentState {
        ProgressAttributes.ContentState(stage: RouteStage.walkingToBus.rawValue,
                                        leftDistance: 35, totalDistance: 70, destination: "포스텍", subDescription: "약 3분 정도 걸려요", maxProgressValue: 0, currentProgressValue: 0, totalBusStops: 10, remainingBusStops: 10)
    }
    
    fileprivate static var onBus: ProgressAttributes.ContentState {
        ProgressAttributes.ContentState(stage: RouteStage.onBus.rawValue, totalDistance: 50, destination: "포항역", subDescription: "2정류장 남았어요", maxProgressValue: 30, currentProgressValue: 30, totalBusStops: 20, remainingBusStops: 2)
    }
}

// ⭐️ 파일 스코프 (전역)에서 선언
#Preview("Notification", as: .content, using: ProgressAttributes.preview) {
    ProgressLiveActivity()
} contentStates: {
    ProgressAttributes.ContentState.walking
    ProgressAttributes.ContentState.onBus
}
