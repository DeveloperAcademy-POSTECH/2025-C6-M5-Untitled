import SwiftUI
import ActivityKit

struct ContentView: View {
    var body: some View {
        VStack {
            Button {
                let attributes = ProgressWidgetAttributes(name: "Timer Sample")
                let contentState = ProgressWidgetAttributes.ContentState(emoji: "😀")
                let content = ActivityContent(state: contentState, staleDate: nil)
                do {
                    _ = try Activity<ProgressWidgetAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                } catch {
                    print("LiveActivityManager: Error in LiveActivityManager: \(error.localizedDescription)")
                }
            }label: {
                Text("Show")
            }
        }
        .padding()
    }
}
