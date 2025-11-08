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
    private var isBusUpdating = false
    
    private var lastWalkingUpdateTime: Date = .distantPast
    private var lastBusProgressUpdateTime: Date = .distantPast
    private var pendingStageUpdate: (nextStage: String, nextDestination: String, totalDistance: Double, remainingBusStops: Int, busTravelTime: Int)?
    private var pendingRemainingBusStops: Int?
    
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
        
        // splitTextToFit을 static 함수로 변경하여 호출
        let adjustedText = splitTextToFit(text: baseText, maxCharactersPerLine: 17)
        
        return adjustedText.replacingOccurrences(of: " ", with: "\u{00a0}")
    }
    
    // static 함수로 변경
    private static func splitTextToFit(text: String, maxCharactersPerLine: Int) -> String {
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
    
    func updateStage(
        nextStage: String,
        nextDestination: String,
        totalDistance: Double,
        remainingBusStops: Int,
        busTravelTime: Int
    ) {
        let timestamp = Date().timeIntervalSince1970
        print("[단계변경 \(String(format: "%.3f", timestamp))] 호출됨 - nextStage: \(nextStage), destination: \(nextDestination)")

        // 활성화된 Live Activity 확인
        guard let activity = Activity<ProgressAttributes>.activities.first else {
            print("[LiveActivity] No active activity found")
            return
        }

        // 내부 static 상태 업데이트
        Self.remainingBusStops = remainingBusStops
        Self.destination = nextDestination
        Self.totalDistance = totalDistance
        Self.busTravelTime = busTravelTime
        Self.leftDistance = totalDistance  // leftDistance도 초기화

        // 현재 단계에 맞는 설명 텍스트
        let subDescription = Self.subDescription(
            for: nextStage,
            leftDistance: totalDistance,
            remainingBusStops: remainingBusStops,
            busTravelTime: busTravelTime
        )

        // 기존 state 기반으로 필요한 값만 교체
        var updatedState = activity.content.state
        
        print("[DEBUG updateStage] 이전 state - stage: \(updatedState.stage), destination: \(updatedState.destination)")
        
        updatedState.stage = nextStage
        updatedState.destination = nextDestination
        updatedState.remainingBusStops = remainingBusStops
        updatedState.busProgress = 0
        updatedState.leftDistance = totalDistance  // leftDistance 업데이트

        updatedState.totalDistance = totalDistance
        updatedState.subDescription = subDescription
        updatedState.busTravelTime = busTravelTime

        // 단계 전환 시에는 진행도 리셋
        updatedState.maxProgressValue = 0
        updatedState.currentProgressValue = 0
        
        print("[DEBUG updateStage] 새로운 state - stage: \(updatedState.stage), destination: \(updatedState.destination)")
        print("[DEBUG updateStage] description will be: \(Self.description(for: nextStage, destination: nextDestination))")
        
        // maxProgress 리셋
        self.maxProgress = 0.0

        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            print("[단계변경 \(String(format: "%.3f", timestamp))] 업데이트 성공 - 새 단계: \(nextStage), destination: \(nextDestination)")
        }
    }
    
    func updateRemainingBusStops(remaining: Int) {
        let timestamp = Date().timeIntervalSince1970
        
        if isBusUpdating {
            print("[남은 정류장 \(String(format: "%.3f", timestamp))] 대기 중 - pendingRemainingBusStops에 저장")
            pendingRemainingBusStops = remaining
            return
        }
        
        guard let activity = Activity<ProgressAttributes>.activities.first else {
            print("[LiveActivity] No active activity found for remaining bus stops update")
            return
        }
        
        Self.remainingBusStops = remaining
        
        var updatedState = activity.content.state
        updatedState.remainingBusStops = remaining
        updatedState.subDescription = Self.subDescription(
            for: updatedState.stage,
            leftDistance: updatedState.leftDistance,
            remainingBusStops: remaining,
            busTravelTime: updatedState.busTravelTime
        )
        
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            print("[남은 정류장 \(String(format: "%.3f", timestamp))] Updated remaining bus stops: \(remaining)")        }
    }
    
    func updateBusProgress(busProgress: Double) {
        let timestamp = Date().timeIntervalSince1970
        
        if isBusUpdating {
            print("[버스 진행률 \(String(format: "%.3f", timestamp))] 업데이트 중이므로 무시됩니다.")
            // 진행률 업데이트는 빈번하므로 pending으로 저장하지 않고 최신값만 처리하도록 무시합니다.
            // 대신, pendingRemainingBusStops에 값이 있다면 다음 업데이트에 처리될 것입니다.
            return
        }
        
        guard let activity = Activity<ProgressAttributes>.activities.first else {
            print("[LiveActivity] No active activity found for bus progress update")
            return
        }
        
        let now = Date()
        guard now.timeIntervalSince(lastBusProgressUpdateTime) >= 1.0 else {
            return
        }
        lastBusProgressUpdateTime = now
        
        isBusUpdating = true
        
        Self.busProgress = busProgress
        
        let currentStage = activity.content.state.stage
        let currentLeftDistance = activity.content.state.leftDistance
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
            
            // 보류된 remainingBusStops가 있다면 반영
            if let pendingRemaining = self.pendingRemainingBusStops {
                updatedState.remainingBusStops = pendingRemaining
                updatedState.subDescription = Self.subDescription(
                    for: updatedState.stage,
                    leftDistance: updatedState.leftDistance,
                    remainingBusStops: pendingRemaining,
                    busTravelTime: updatedState.busTravelTime
                )
                print("[버스 진행률 \(String(format: "%.3f", timestamp))] 보류된 남은 정류장 \(pendingRemaining) 반영")
            }
            
            Task {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                print("[버스 진행률 \(String(format: "%.3f", timestamp))] 업데이트 완료. progressValue: \(progressValue)")
                self.isBusUpdating = false // 업데이트 완료
                
                // 보류된 remainingBusStops가 반영되었으므로 초기화
                self.pendingRemainingBusStops = nil
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
