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
    
    private var lastWalkingUpdateTime: Date = .distantPast
    private var pendingStageUpdate: (nextStage: String, nextDestination: String, totalDistance: Double, remainingBusStops: Int, busTravelTime: Int)?

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
            let activity = try Activity<ProgressAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil)
            )
            currentActivity = activity
            print("Activity started successfully with stage: \(stage)")
        } catch {
            print("Failed to start activity: \(error)")
        }
    }
    
    func updateWalkingActivity(stage: String, newLeftDistance: Double) {
        let timestamp = Date().timeIntervalSince1970
        
        
        guard let currentActivity = currentActivity else { return }
        
        guard !isStageUpdating else { return }
        
        // 마지막 업데이트로부터 1초 이상 지났는지 확인
        let now = Date()
        guard now.timeIntervalSince(lastWalkingUpdateTime) >= 1.0 else {
            return
        }
        lastWalkingUpdateTime = now
        
        let currentProgress = Self.progress(for: stage, totalDistance: Self.totalDistance, leftDistance: newLeftDistance, busProgess: 0, remainingBusStops: 0)
        maxProgress = max(maxProgress, currentProgress)
        let subDescription = Self.subDescription(for: stage, leftDistance: newLeftDistance, remainingBusStops: 0, busTravelTime: 0)
                
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
            await currentActivity.update(ActivityContent(state: updatedState, staleDate: nil))
            print("[걷기 \(String(format: "%.3f", timestamp))] 업데이트 완료")
        }
    }
    
    func updateStage(nextStage: String, nextDestination: String, totalDistance: Double, remainingBusStops: Int, busTravelTime: Int) {
        let timestamp = Date().timeIntervalSince1970
        print("[단계변경 \(String(format: "%.3f", timestamp))] 호출됨 - nextStage: \(nextStage), destination: \(nextDestination)")
        
        // 업데이트 중이면 저장하고 대기
        if isStageUpdating {
            print("[단계변경 \(String(format: "%.3f", timestamp))] 대기 중 - pendingStageUpdate에 저장")
            pendingStageUpdate = (nextStage, nextDestination, totalDistance, remainingBusStops, busTravelTime)
            return
        }
        
        isStageUpdating = true

        
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
        
        print("[단계변경 \(String(format: "%.3f", timestamp))] 0.5초 대기 시작...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let afterTimestamp = Date().timeIntervalSince1970
            let delayActual = afterTimestamp - timestamp
            
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
                print("[단계변경 \(String(format: "%.3f", timestamp))] 업데이트 성공 - 새 단계: \(nextStage)")
                self.isStageUpdating = false
                print("[단계변경 \(String(format: "%.3f", timestamp))] 잠금 해제 (성공)")
                
                // 대기 중인 업데이트 처리
                if let pending = self.pendingStageUpdate {
                    print("[대기된 업데이트] 처리 시작 - stage: \(pending.nextStage)")
                    self.pendingStageUpdate = nil
                    self.updateStage(
                        nextStage: pending.nextStage,
                        nextDestination: pending.nextDestination,
                        totalDistance: pending.totalDistance,
                        remainingBusStops: pending.remainingBusStops,
                        busTravelTime: pending.busTravelTime
                    )
                }
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
                await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(3)))
            }
            currentActivity = nil
            print("Activity ended.")
        }
    }
}
