// ProgressWidgetManager.swift

import Foundation
import ActivityKit

final class ProgressLiveActivityManager {
    
    static let shared = ProgressLiveActivityManager()
    
    static var totalDistance: Double = 1.0
    static var leftDistance: Double = 0.0
    static var totalBusStops: Int = 1
    static var remainingBusStops: Int = 0
    static var destination: String = ""
    
    private var currentActivity: Activity<ProgressAttributes>?
    private var maxProgress: Double = 0.0
    
    private init() {}
    
    static func progress(for stage: String, totalDistance: Double, leftDistance: Double, totalBusStops: Int, remainingBusStops: Int) -> Double {
        let total = max(1.0, totalDistance)
        let left = leftDistance
        let totalStops = Double(totalBusStops)
        let passedStops = totalStops - Double(remainingBusStops)
        
        switch stage {
        case "walkingToBus", "walkingToDestination":
            return max(0, min((total - left) / total, 1.0))
        case "waitingForBus":
            return 0.0
        case "onBus":
            return totalStops > 0 ? max(0, min(passedStops / totalStops, 1.0)) : 0.0
        default:
            return 0.0
        }
    }
    
    static func description(for stage: String, destination: String) -> String {
        switch stage {
        case "walkingToBus":
            return "\(destination)까지 걷기"
        case "waitingForBus":
            return "\(destination)에서 승차"
        case "walkingToDestination":
            return "\(destination)까지 걷기"
        case "onBus":
            return "\(destination)에서 하차"
        default:
            return ""
        }
    }
    
    static func subDescription(for stage: String, leftDistance: Double) -> String {
        switch stage {
        case "walkingToBus", "walkingToDestination":
            let minutesLeft = Int(leftDistance / 70)
            return "\(minutesLeft)분 남았어요"
        case "onBus":
            return "\(remainingBusStops)정류장 남았어요"
        case "waitingForBus":
            return "min동안 타아해요"
        default:
            return ""
        }
    }
    
    func startActivity(totalDistance: Double, totalBusStops: Int, stage: String, destination: String) {
        Self.totalDistance = totalDistance
        Self.totalBusStops = totalBusStops
        Self.destination = destination
        
        let attributes = ProgressAttributes()
        let initialSubDesc = ProgressLiveActivityManager.subDescription(for: stage, leftDistance: Self.totalDistance)
        
        let contentState = ProgressAttributes.ContentState(
            stage: stage,
            leftDistance: Self.leftDistance,
            totalDistance: Self.totalDistance,
            destination: destination,
            subDescription: initialSubDesc,
            maxProgressValue: 0.0,
            currentProgressValue: 0.0,
            totalBusStops: Self.totalBusStops,
            remainingBusStops: Self.remainingBusStops
            )
            
            do {
                let activity = try Activity<ProgressAttributes>.request(attributes: attributes, contentState: contentState)
                currentActivity = activity
                print("Activity started successfully with stage: \(stage)")
            } catch {
                print("Failed to start activity: \(error)")
            }
    }
    
    func updateWalkingActivity(newLeftDistance: Double) {
        guard let currentActivity = currentActivity else { return }
        let stage = currentActivity.contentState.stage
        
        let currentProgress = Self.progress(for: stage, totalDistance: Self.totalDistance, leftDistance: newLeftDistance, totalBusStops: 0, remainingBusStops: 0)
        
        maxProgress = max(maxProgress, currentProgress)
        
        let subDescription = Self.subDescription(for: stage, leftDistance: newLeftDistance)
        print("Updated subDescription: \(subDescription)")
        
        let updatedContentState = ProgressAttributes.ContentState(
            stage: stage,
            leftDistance: newLeftDistance,
            totalDistance: Self.totalDistance,
            destination: Self.destination,
            subDescription: subDescription,
            maxProgressValue: maxProgress,
            currentProgressValue: currentProgress,
            totalBusStops: 0,
            remainingBusStops: 0
        )
        
        Task {
            await currentActivity.update(using: updatedContentState)
        }
    }
    
    func updateStage(stage: String, destination: String, totalBusStops: Int, totalDistance: Double) {
        guard let currentActivity = currentActivity else { return }

        Self.destination = destination
        Self.totalBusStops = totalBusStops
        Self.totalDistance = totalDistance

        var updatedState = currentActivity.content.state
        updatedState.stage = stage
        updatedState.destination = destination
        updatedState.totalBusStops = totalBusStops
        updatedState.totalDistance = totalDistance

        Task {
            do {
                await currentActivity.update(using: updatedState)
                print("[LiveActivity] updateStage 성공: \(stage)")
            } catch {
                print("[LiveActivity] updateStage 실패:", error)
            }
        }
    }

    func updateRemainingBusStops(remaining: Int) {
        guard let currentActivity = currentActivity else { return }
        let stage = currentActivity.contentState.stage
        
        Self.remainingBusStops = remaining
        
        // 현재 버스 진행률 계산
        let totalStops = Double(Self.totalBusStops)
        let passedStops = totalStops - Double(remaining)
        let currentBusProgress = totalStops > 0 ? max(0, min(passedStops / totalStops, 1.0)) : 0.0

        // maxProgressValue를 현재 버스 진행률로 설정 (역행 방지 로직 사용하지 않음)
        let newMaxProgressValue = currentBusProgress
        
        // subDescription 업데이트
        let subDescription = Self.subDescription(for: stage, leftDistance: currentActivity.contentState.leftDistance ?? 0)
        
        let updatedContent = ProgressAttributes.ContentState(
            stage: stage,
            leftDistance: currentActivity.contentState.leftDistance,
            totalDistance: currentActivity.contentState.totalDistance,
            destination: currentActivity.contentState.destination,
            subDescription: subDescription,
            maxProgressValue: newMaxProgressValue,
            currentProgressValue: currentBusProgress,
            totalBusStops: Self.totalBusStops,
            remainingBusStops: remaining
        )

        Task {
            await currentActivity.update(using: updatedContent)
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

extension ProgressAttributes.ContentState {
    private struct AssociatedKeys {
        static var subDescription = "subDescription"
    }
    private var _subDescription: String? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.subDescription) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.subDescription, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
