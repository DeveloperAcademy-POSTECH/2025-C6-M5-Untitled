import SwiftUI

class Journey {
    let id = UUID()
    var journey: [LocationNode]
    
    init(journey: [LocationNode]) {
        self.journey = journey
    }
}
