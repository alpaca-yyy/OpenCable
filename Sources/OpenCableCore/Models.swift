import Foundation

public struct Port: Codable, Identifiable, Equatable {
    public var id: String
    public var number: Int?
    public var connected: Bool?
    public var activeTransports: [String]
    public var supportedTransports: [String]
    public var orientation: Int?
    public var activeCable: Bool?
    public var opticalCable: Bool?
    public var displayActive: Bool?
    public var connectionDescription: String?
}
public struct PowerProfile: Codable, Equatable {
    public var volts: Double
    public var amps: Double
    public var watts: Double { volts * amps }
}
public struct Power: Codable, Equatable {
    public var externalConnected: Bool?
    public var charging: Bool?
    public var adapterWatts: Double?
    public var negotiatedVolts: Double?
    public var negotiatedAmps: Double?
    public var inputWatts: Double?
    public var batteryPercent: Double?
    public var profiles: [PowerProfile]
    public var warnings: [String]
}
public struct USBDevice: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var vendorID: Int?
    public var productID: Int?
    public var speedCode: Int?
    public var locationID: UInt64?
}
public struct Snapshot: Codable {
    public var timestamp: Date
    public var ports: [Port]
    public var power: Power
    public var usbDevices: [USBDevice]
    public var warnings: [String]
    public var connectedCount: Int { ports.filter { $0.connected == true }.count }
    public func json() throws -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601
        return try e.encode(self)
    }
}
