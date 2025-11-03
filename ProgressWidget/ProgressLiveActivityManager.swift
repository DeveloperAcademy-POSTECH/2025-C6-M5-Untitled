// ProgressWidgetManager.swift

import Foundation
import ActivityKit

final class ProgressLiveActivityManager {
    
    static let shared = ProgressLiveActivityManager()
    
    static var totalDistance: Double = 1.0
    static var leftDistance: Double = 0.0
    static var busProgress: Double = 0.0
    static var remainingBusStops: Int = 0
    static var destination: String = ""
    static var busTravelTime: Int = 0
    static var maxProgressValue: Double = 0.0
    static var currentProgressValue: Double = 0.0
    
    private var currentActivity: Activity<ProgressAttributes>?
    private var maxProgress: Double = 0.0
    private var isStageUpdating = false
    
    private init() {}
    
    static func progress(for stage: String, totalDistance: Double, leftDistance: Double, busProgess: Double, remainingBusStops: Int) -> Double {
        let total = max(1.0, totalDistance)
        let left = leftDistance
        let busProgress = busProgress
        
        switch stage {
        case "walkingToBus", "walkingToDestination":
            return max(0, min((total - left) / total, 1.0))
        case "waitingForBus":
            return 0.0
        case "onBus":
            return busProgress
        default:
            return 0.0
        }
    }

    private func splitTextToFit(text: String, maxCharactersPerLine: Int) -> String {
        guard text.count > maxCharactersPerLine else {
            return text // 1줄이면 그대로 반환
        }
        
        // 최대 문자 수까지 문자열을 자릅니다.
        let index = text.index(text.startIndex, offsetBy: maxCharactersPerLine)
        let firstLine = String(text[..<index])
        let remainingText = String(text[index...])
        
        // 두 번째 줄의 시작 공백 제거
        let trimmedRemainingText = remainingText.drop { $0.isWhitespace }
            return "\(firstLine)\n\(trimmedRemainingText)"
    }


    static func description(for stage: String, destination: String) -> String {
        
        let baseText: String
        switch stage {
        case "walkingToBus", "walkingToDestination":
            baseText = "\(destination)까지 걷기"
        case "waitingForBus":
            baseText = "\(destination)에서 승차"
        case "onBus":
            baseText = "\(destination)에서 하차"
        default:
            return ""
        }
        
        let manager = ProgressLiveActivityManager.shared
        let adjustedText = manager.splitTextToFit(text: baseText, maxCharactersPerLine: 17)
        
        return adjustedText.replacingOccurrences(of: " ", with: "\u{00a0}")
    }
    
    static func subDescription(for stage: String, leftDistance: Double, remainingBusStops: Int, busTravelTime: Int) -> String {
        switch stage {
        case "walkingToBus", "walkingToDestination":
            let minutesLeft = Int(leftDistance / 70) + 1
            return "\(minutesLeft)분 남았어요"
        case "onBus":
            return "\(remainingBusStops)정류장 남았어요"
        case "waitingForBus":
            let hours = busTravelTime / 60
            let minutes = busTravelTime % 60
            if hours > 0 && minutes == 0 {
                return "\(hours)시간 동안 타야해요"
            } else if hours > 0 {
                return "\(hours)시간 \(minutes)분 동안 타아해요"
            } else {
                return "\(minutes)분 동안 타야해요"
            }
        default:
            return ""
        }
    }
    
    func startActivity(totalDistance: Double, stage: String, destination: String, remainingBusStops: Int, busTravelTime: Int) {
        Self.totalDistance = totalDistance
        Self.destination = destination
        Self.remainingBusStops = remainingBusStops
        Self.busTravelTime = busTravelTime
        Self.maxProgressValue = 0.0
        Self.currentProgressValue = 0.0
        self.maxProgress = 0.0
        
        let attributes = ProgressAttributes()
        
        let contentState = ProgressAttributes.ContentState(
            stage: stage,
            leftDistance: Self.leftDistance,
            totalDistance: Self.totalDistance,
            destination: Self.destination,
            subDescription: Self.subDescription(for: stage, leftDistance: Self.leftDistance, remainingBusStops: remainingBusStops, busTravelTime: busTravelTime),
            maxProgressValue: Self.maxProgressValue,
            currentProgressValue: Self.currentProgressValue,
            busProgress: Self.busProgress,
            remainingBusStops: Self.remainingBusStops,
            busTravelTime: Self.busTravelTime
        )
        
        do {
            let activity = try Activity<ProgressAttributes>.request(attributes: attributes, contentState: contentState)
            currentActivity = activity
            print("Activity started successfully with stage: \(stage)")
        } catch {
            print("Failed to start activity: \(error)")
        }
    }
    
    func updateWalkingActivity(stage: String, newLeftDistance: Double) {
        guard let currentActivity = currentActivity else { return }
        guard !isStageUpdating else { return } // 🚫 stage 업데이트 중이면 무시
        
        let currentProgress = Self.progress(for: stage, totalDistance: Self.totalDistance, leftDistance: newLeftDistance, busProgess: 0, remainingBusStops: 0)
        
        maxProgress = max(maxProgress, currentProgress)
        
        let subDescription = Self.subDescription(for: stage, leftDistance: newLeftDistance, remainingBusStops: 0, busTravelTime: 0)
        print("Updated subDescription: \(subDescription)")
        
        let updatedState = ProgressAttributes.ContentState(
            stage: stage,
            leftDistance: newLeftDistance,
            totalDistance: Self.totalDistance,
            destination: Self.destination,
            subDescription: subDescription,
            maxProgressValue: maxProgress,
            currentProgressValue: currentProgress,
            busProgress: 0,
            remainingBusStops: 0,
            busTravelTime: Self.busTravelTime
        )
        
        Task {
            await currentActivity.update(using: updatedState)
        }
    }
    
    func updateStage(nextStage: String, nextDestination: String, totalDistance: Double, remainingBusStops: Int, busTravelTime: Int) {
        guard !isStageUpdating else {
            print("[LiveActivity] Stage update skipped - already updating")
            return
        }
        isStageUpdating = true  // 🚫 다른 업데이트 잠금
        
        guard let activity = Activity<ProgressAttributes>.activities.first else {
            print("[LiveActivity] No active activity found")
            isStageUpdating = false
            return
        }
        
        Self.remainingBusStops = remainingBusStops
        Self.destination = nextDestination
        Self.totalDistance = totalDistance
        Self.busTravelTime = busTravelTime
        
        let subDescription = Self.subDescription(
            for: nextStage,
            leftDistance: totalDistance,
            remainingBusStops: remainingBusStops,
            busTravelTime: busTravelTime
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var updatedState = activity.content.state
            updatedState.stage = nextStage
            updatedState.destination = nextDestination
            updatedState.remainingBusStops = remainingBusStops
            updatedState.busProgress = 0
            updatedState.totalDistance = totalDistance
            updatedState.subDescription = subDescription
            updatedState.busTravelTime = busTravelTime
            updatedState.maxProgressValue = 0
            updatedState.currentProgressValue = 0
            
            Task {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                print("[LiveActivity] Successfully updated to stage: \(nextStage)")
                self.isStageUpdating = false // ✅ 해제
            }
        }
    }
    
    func updateRemainingBusStops(remaining: Int) {
        guard let activity = Activity<ProgressAttributes>.activities.first else {
            print("[LiveActivity] No active activity found for remaining bus stops update")
            return
        }
        
        Self.remainingBusStops = remaining
        
        var updatedState = activity.content.state
        updatedState.remainingBusStops = remaining
        updatedState.subDescription = Self.subDescription(
            for: updatedState.stage,
            leftDistance: updatedState.leftDistance ?? 0,
            remainingBusStops: remaining,
            busTravelTime: updatedState.busTravelTime
        )
        
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            print("[LiveActivity] Updated remaining bus stops: \(remaining)")
        }
    }
    
    func updateBusProgress(busProgress: Double) {
        guard let activity = Activity<ProgressAttributes>.activities.first else {
            print("[LiveActivity] No active activity found for bus progress update")
            return
        }
        
        Self.busProgress = busProgress
        
        let currentStage = activity.content.state.stage
        let currentLeftDistance = activity.content.state.leftDistance ?? activity.content.state.totalDistance
        let currentRemainingBusStops = activity.content.state.remainingBusStops
        
        // 현재 progress 계산
        let progressValue = ProgressLiveActivityManager.progress(
            for: currentStage,
            totalDistance: activity.content.state.totalDistance,
            leftDistance: currentLeftDistance,
            busProgess: busProgress,
            remainingBusStops: currentRemainingBusStops
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var updatedState = activity.content.state
            updatedState.busProgress = busProgress
            updatedState.currentProgressValue = progressValue
            updatedState.maxProgressValue = max(updatedState.maxProgressValue, progressValue)
            
            Task {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                print("[LiveActivity] Updated bus progress: \(busProgress), progressValue: \(progressValue)")
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
