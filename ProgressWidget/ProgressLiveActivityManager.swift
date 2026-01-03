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
    static var timeTillBusArrival: Int = 0
    static var maxProgressValue: Double = 0.0
    static var currentProgressValue: Double = 0.0
    
    private var currentActivity: Activity<ProgressAttributes>?
    private var maxProgress: Double = 0.0
    
    private var lastWalkingUpdateTime: Date = .distantPast
    private var lastBusProgressUpdateTime: Date = .distantPast
    private var pendingStageUpdate: (nextStage: String, nextDestination: String, totalDistance: Double, remainingBusStops: Int, timeTillBusArrival: Int)?
    private var pendingRemainingBusStops: Int?
    private var isBusProgressUpdating = false
    private var isRemainingStopsUpdating = false
    
    private let updateQueue = DispatchQueue(label: "com.busroad.liveactivity.updateQueue")
    
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
        let adjustedText = splitTextToFit(text: baseText, maxCharactersPerLine: 16)
        
        return adjustedText.replacingOccurrences(of: " ", with: "\u{00a0}")
    }
    
    static func expandedDescription(for stage: String, destination: String) -> String {
        
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
    
    static func subDescription(for stage: String, leftDistance: Double, remainingBusStops: Int, timeTillBusArrival: Int) -> String {
        switch stage {
        case "walkingToBus", "walkingToDestination":
            let minutesLeft = Int(leftDistance / 70) + 1
            let walkingHours = minutesLeft / 60
            let walkingMinutes = minutesLeft % 60
            if walkingHours > 0 && walkingMinutes == 0 {
                return "\(walkingHours)시간 남았어요"
            } else if walkingHours > 0 {
                return "\(walkingHours)시간 \(walkingMinutes)분 남았어요"
            } else if leftDistance < 20 {
                return "목적지 근처에요"
            } else {
                return "\(walkingMinutes)분 남았어요"
            }
        case "onBus":
            if remainingBusStops <= 1 {
                return "이번 정류장에서 내리세요"
            } else{
                return "\(remainingBusStops)정류장 남았어요"
            }
        case "waitingForBus":
            let hours = timeTillBusArrival / 3600
            let minutes = (timeTillBusArrival % 3600) / 60
            
            if timeTillBusArrival == -1 {
                return "n번 버스가 지나갔어요"
            } else if timeTillBusArrival == 1 {
                return "버스가 곧 도착해요"
            } else if hours > 0 && minutes == 0 {
                return "\(hours)시간 후 버스가 도착해요"
            } else if hours > 0 {
                return "\(hours)시간 \(minutes)분 후 버스가 도착해요"
            } else {
                return "\(minutes)분 후 버스가 도착해요"
            }
        default:
            return ""
        }
    }
    
    func startActivity(totalDistance: Double, stage: String, destination: String, remainingBusStops: Int, timeTillBusArrival: Int) {
        Self.totalDistance = totalDistance
        Self.destination = destination
        Self.remainingBusStops = remainingBusStops
        Self.timeTillBusArrival = timeTillBusArrival
        Self.maxProgressValue = 0.0
        Self.currentProgressValue = 0.0
        self.maxProgress = 0.0
        
        let attributes = ProgressAttributes()
        
        let contentState = ProgressAttributes.ContentState(
            stage: stage,
            leftDistance: Self.leftDistance,
            totalDistance: Self.totalDistance,
            destination: Self.destination,
            subDescription: Self.subDescription(for: stage, leftDistance: Self.leftDistance, remainingBusStops: remainingBusStops, timeTillBusArrival: timeTillBusArrival),
            maxProgressValue: Self.maxProgressValue,
            currentProgressValue: Self.currentProgressValue,
            busProgress: Self.busProgress,
            remainingBusStops: Self.remainingBusStops,
            timeTillBusArrival: Self.timeTillBusArrival
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
    
    func updateWalkingActivity(newLeftDistance: Double) {
        let timestamp = Date().timeIntervalSince1970
        
        guard let currentActivity = currentActivity else { return }
        
        // 너무 자주 업데이트 방지
        let now = Date()
        guard now.timeIntervalSince(lastWalkingUpdateTime) >= 1.0 else {
            return
        }
        lastWalkingUpdateTime = now
        
        // 현재 Live Activity의 실제 stage 확인
        let currentStage = currentActivity.content.state.stage
        
        // 이미 waitingForBus / onBus / walkingToDestination 등으로 넘어갔으면 걷기 업데이트 무시
        guard currentStage == RouteStage.walkingToBus.rawValue ||
                currentStage == RouteStage.walkingToDestination.rawValue else {
            print("[걷기 \(String(format: "%.3f", timestamp))] stage 불일치 (current=\(currentStage)) → 업데이트 무시")
            return
        }
        
        // canonical stage는 currentStage를 쓴다 (파라미터 stage로 덮어쓰지 않음)
        let effectiveStage = currentStage
        
        let currentProgress = Self.progress(
            for: effectiveStage,
            totalDistance: Self.totalDistance,
            leftDistance: newLeftDistance,
            busProgess: 0,
            remainingBusStops: 0
        )
        
        maxProgress = max(maxProgress, currentProgress)
        Self.leftDistance = newLeftDistance
        
        let subDescription = Self.subDescription(
            for: effectiveStage,
            leftDistance: newLeftDistance,
            remainingBusStops: 0,
            timeTillBusArrival: 0
        )
        
        // 기존 state 기반으로 필요한 값만 갱신
        var updatedState = currentActivity.content.state
        updatedState.leftDistance = newLeftDistance
        updatedState.totalDistance = Self.totalDistance
        updatedState.maxProgressValue = maxProgress
        updatedState.currentProgressValue = currentProgress
        updatedState.subDescription = subDescription
        
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
        timeTillBusArrival: Int
    ) async {
        let timestamp = Date().timeIntervalSince1970
        print("[단계변경 \(String(format: "%.3f", timestamp))] 호출됨 - nextStage: \(nextStage), destination: \(nextDestination)")
        
        // 활성화된 Live Activity 확인
        guard let activity = self.currentActivity else {
            print("[LiveActivity] currentActivity nil")
            return
        }
        
        // 내부 static 상태 업데이트
        Self.remainingBusStops = remainingBusStops
        Self.destination = nextDestination
        Self.totalDistance = totalDistance
        Self.timeTillBusArrival = timeTillBusArrival
        Self.leftDistance = totalDistance
        
        // 현재 단계에 맞는 설명 텍스트
        let subDescription = Self.subDescription(
            for: nextStage,
            leftDistance: totalDistance,
            remainingBusStops: remainingBusStops,
            timeTillBusArrival: timeTillBusArrival
        )
        
        // 기존 state 기반으로 필요한 값만 교체
        var updatedState = activity.content.state
        
        print("[DEBUG updateStage] 이전 state - stage: \(updatedState.stage), destination: \(updatedState.destination)")
        
        updatedState.stage = nextStage
        updatedState.destination = nextDestination
        updatedState.remainingBusStops = remainingBusStops
        updatedState.busProgress = 0
        updatedState.leftDistance = totalDistance
        
        updatedState.totalDistance = totalDistance
        updatedState.subDescription = subDescription
        updatedState.timeTillBusArrival = timeTillBusArrival
        
        // 단계 전환 시에는 진행도 리셋
        updatedState.maxProgressValue = 0
        updatedState.currentProgressValue = 0
        
        print("[DEBUG updateStage] 새로운 state - stage: \(updatedState.stage), destination: \(updatedState.destination)")
        print("[DEBUG updateStage] description will be: \(Self.description(for: nextStage, destination: nextDestination))")
        
        self.maxProgress = 0.0
        
        await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        print("[단계변경 \(String(format: "%.3f", timestamp))] 업데이트 성공 - 새 단계: \(nextStage), destination: \(nextDestination)")
    }
    
    func updateRemainingBusStops(remaining: Int, currentStage: String) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 자기 자신의 플래그만 체크
            guard !self.isRemainingStopsUpdating else {
                self.pendingRemainingBusStops = remaining
                return
            }
            
            self.isRemainingStopsUpdating = true
            
            guard let activity = Activity<ProgressAttributes>.activities.first else {
                self.isRemainingStopsUpdating = false
                return
            }
            
            Self.remainingBusStops = remaining
            
            var updatedState = activity.content.state
            updatedState.remainingBusStops = remaining
            updatedState.stage = currentStage
            updatedState.subDescription = Self.subDescription(
                for: updatedState.stage,
                leftDistance: updatedState.leftDistance,
                remainingBusStops: remaining,
                timeTillBusArrival: updatedState.timeTillBusArrival
            )
            
            Task {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                print("[남은 정류장] Updated: \(remaining)")
                
                self.isRemainingStopsUpdating = false
                
                if let pending = self.pendingRemainingBusStops {
                    self.pendingRemainingBusStops = nil
                    self.updateRemainingBusStops(remaining: pending, currentStage: currentStage)
                }
            }
        }
    }
    
    func updateBusArrivalTime(timeTillBusArrival: Int, currentStage: String) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastBusProgressUpdateTime) >= 1.0 else {
                return
            }

            guard !self.isBusProgressUpdating else {
                return
            }

            self.isBusProgressUpdating = true
            self.lastBusProgressUpdateTime = now

            guard let activity = Activity<ProgressAttributes>.activities.first else {
                self.isBusProgressUpdating = false
                return
            }

            Self.timeTillBusArrival = Int(timeTillBusArrival)

            var updatedState = activity.content.state
            updatedState.timeTillBusArrival = Int(timeTillBusArrival)
            updatedState.stage = currentStage
            updatedState.subDescription = Self.subDescription(
                for: updatedState.stage,
                leftDistance: updatedState.leftDistance,
                remainingBusStops: updatedState.remainingBusStops,
                timeTillBusArrival: Int(timeTillBusArrival)
            )

            Task {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                print("[버스 도착 시간] 업데이트 완료: \(timeTillBusArrival)초")
                self.isBusProgressUpdating = false
            }
        }
    }
    
    func updateBusProgress(busProgress: Double, currentStage: String) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            guard now.timeIntervalSince(self.lastBusProgressUpdateTime) >= 1.0 else {
                return
            }
            
            // 자기 자신의 플래그만 체크
            guard !self.isBusProgressUpdating else {
                return
            }
            
            self.isBusProgressUpdating = true
            self.lastBusProgressUpdateTime = now
            
            guard let activity = Activity<ProgressAttributes>.activities.first else {
                self.isBusProgressUpdating = false
                return
            }
            
            Self.busProgress = busProgress
            
            var updatedState = activity.content.state
            updatedState.stage = currentStage
            updatedState.busProgress = busProgress
            updatedState.currentProgressValue = busProgress
            updatedState.maxProgressValue = max(updatedState.maxProgressValue, busProgress)
            
            Task {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                print("[버스 진행률] 업데이트 완료: \(busProgress)")
                
                self.isBusProgressUpdating = false
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

