import SwiftUI
import MapKit

class LocationNode {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var nodeType: NodeType
    var transportType: TransportType
    
    // if transportType == bus
    var busStopId: String?
    var busNumber: String?
    
    init(coordinate: CLLocationCoordinate2D, nodeType: NodeType, transportType: TransportType) {
        self.coordinate = coordinate
        self.nodeType = nodeType
        self.transportType = transportType
    }
    
    init(coordinate: CLLocationCoordinate2D, nodeType: NodeType, transportType: TransportType, busStopId: String, busNumber: String) {
        self.coordinate = coordinate
        self.nodeType = nodeType
        self.transportType = transportType
        self.busStopId = busStopId
        self.busNumber = busNumber
    }
}
