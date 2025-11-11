import Foundation

struct BusLocationResponse: Codable {
    let response: BusLocationResponseBody
}

struct BusLocationResponseBody: Codable {
    let header: ResponseHeader
    let body: BusLocationBody?
}

struct BusLocationBody: Codable {
    let items: BusLocationItems?
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int
}

struct BusLocationItems: Codable {
    let item: [BusLocationItem]
    
    enum CodingKeys: String, CodingKey {
        case item
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        if let _ = try? c.decode(String.self, forKey: .item) {
            self.item = []
        } else if let arr = try? c.decode([BusLocationItem].self, forKey: .item) {
            self.item = arr
        } else if let one = try? c.decode(BusLocationItem.self, forKey: .item) {
            self.item = [one]
        } else {
            self.item = []
        }
    }
}

struct BusLocationItem: Codable, Identifiable {
    var id = UUID()
    
    let gpslati: Double
    let gpslong: Double
    let nodeid: String
    let nodenm: String
    let nodeord: Int
    let routenm: String?
    let routetp: String?
    let vehicleno: String
    
    enum CodingKeys: String, CodingKey {
        case gpslati, gpslong, nodeid, nodenm, nodeord, routenm, routetp, vehicleno
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        gpslati = (try? c.decode(Double.self, forKey: .gpslati))
        ?? Double((try? c.decode(String.self, forKey: .gpslati)) ?? "") ?? 0
        
        gpslong = (try? c.decode(Double.self, forKey: .gpslong))
        ?? Double((try? c.decode(String.self, forKey: .gpslong)) ?? "") ?? 0
        
        nodeid = (try? c.decode(String.self, forKey: .nodeid)) ?? ""
        nodenm = (try? c.decode(String.self, forKey: .nodenm)) ?? ""
        
        if let ord = try? c.decode(Int.self, forKey: .nodeord) {
            nodeord = ord
        } else if let ordStr = try? c.decode(String.self, forKey: .nodeord),
                  let ord = Int(ordStr) {
            nodeord = ord
        } else {
            nodeord = 0
        }
        
        routenm = try? c.decode(String.self, forKey: .routenm)
        routetp = try? c.decode(String.self, forKey: .routetp)
        
        if let v = try? c.decode(String.self, forKey: .vehicleno) {
            vehicleno = v
        } else if let vInt = try? c.decode(Int.self, forKey: .vehicleno) {
            vehicleno = String(vInt)
        } else {
            vehicleno = ""
        }
    }
}
