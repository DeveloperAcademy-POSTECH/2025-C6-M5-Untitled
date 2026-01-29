import Combine
import SwiftUI

@MainActor
final class OnRideViewModel: ObservableObject {
    
    @Published var journey: Journey?
    @Published var index: Int?
    @Published var stopName: String = ""
    @Published var englishStopName: String = ""
    @Published var busLegIndex: Int = 0 {
        didSet {
            setupBusLeg(busLegIndex: busLegIndex)
        }
    }
    
    private let journeyManager: JourneyManager
    private var bag = Set<AnyCancellable>()
    
    init(journeyManager: JourneyManager? = nil) {
        self.journeyManager = journeyManager ?? .shared
        self.journeyManager.$selectedJourney
            .assign(to: &$journey)
        self.journeyManager.$journeyIndex
            .assign(to: &$index)
    }
    
    // MARK: - 하차정류장이름
    private func setupBusLeg(busLegIndex: Int) {
        guard let journey = journeyManager.selectedJourney else {
            print("선택된 여정이 없습니다.")
            return
        }
        
        if let alight = journey.alightStop(ofBusLeg: busLegIndex) {
            self.stopName = alight.name
            self.englishStopName = alight.englishName ?? self.stopName
        }
    }
}
