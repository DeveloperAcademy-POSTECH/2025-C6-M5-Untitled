// ProgressWidgetManager.swift

import Foundation
import ActivityKit

final class ProgressLiveActivityManager {

    static let shared = ProgressLiveActivityManager()

    static var totalDistance: Double = 1.0
    static var leftDistance: Double = 0.0
    static var totalBusStops: Int = 1
    static var passedBusStops: Int = 0

    private var currentActivity: Activity<ProgressAttributes>?

    private init() {}

    static func progress(for stage: String, totalDistance: Double, leftDistance: Double) -> Double {
        let total = max(1.0, totalDistance)
        let left = leftDistance

        switch stage {
        case "도보", "목적지 도보":
            return max(0, min((total - left) / total, 1.0))
        case "버스 대기":
            return 0.0
        case "승차 중":
            return totalBusStops > 0 ? Double(passedBusStops) / Double(totalBusStops) : 0.0
        case "도착":
            return 1.0
        default:
            return 0.0
        }
    }

    func startActivity(journey: JourneyLite, stage: String, journeyIndex: Int, isBeforeRide: Bool) {
            
            for node in journey.nodes {
                if case .walk(let walkNode) = node {
                    Self.totalDistance = Double(walkNode.totalDistance)
                    print("총 이동 거리 설정: \(Self.totalDistance)")
                    break
                }
            }
                    
            let attributes = ProgressAttributes()
            
        let contentState = ProgressAttributes.ContentState(stage: stage, leftDistance: Self.leftDistance, totalDistance: Self.totalDistance)
                
            do {
                let activity = try Activity<ProgressAttributes>.request(attributes: attributes, contentState: contentState)
                currentActivity = activity
                print("Activity started successfully with stage: \(stage)")
            } catch {
                print("Failed to start activity: \(error)")
            }
        }

        func updateActivity(newLeftDistance: Double, stage: String) {
            Self.leftDistance = newLeftDistance

            let updatedContentState = ProgressAttributes.ContentState(
                stage: stage,
                leftDistance: newLeftDistance,
                totalDistance: ProgressLiveActivityManager.totalDistance
            )
                  
            Task {
                if let activity = currentActivity {
                    await activity.update(using: updatedContentState)
                }
            }
        }

    func endActivity() {
        Task {
            for activity in Activity<ProgressAttributes>.activities {
                await activity.end(dismissalPolicy: .after(Date().addingTimeInterval(3)))
            }
            currentActivity = nil
            print("Activity ended.")
        }
    }
}
