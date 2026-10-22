import XCTest
@testable import OpenCableCore
final class HardwareTests: XCTestCase {
    func testPowerUnitsAndChargerProfiles() {
        let p = HardwareReader.parsePower(["ExternalConnected": true, "AdapterDetails": ["Watts": 45, "AdapterVoltage": 20000, "Current": 2250, "UsbHvcMenu": [["MaxVoltage": 5000, "MaxCurrent": 3000], ["MaxVoltage": 20000, "MaxCurrent": 2250]]], "PowerTelemetryData": ["SystemPowerIn": 43462], "CurrentCapacity": 60, "MaxCapacity": 100])
        XCTAssertEqual(p.inputWatts!, 43.462, accuracy: 0.0001)
        XCTAssertEqual(p.negotiatedVolts, 20); XCTAssertEqual(p.negotiatedAmps, 2.25)
        XCTAssertEqual(p.adapterWatts, 45); XCTAssertEqual(p.batteryPercent, 60)
        XCTAssertEqual(p.profiles.map(\.watts), [15, 45])
    }
    func testDisconnectedStateDoesNotLeakStaleCableOrPowerValues() {
        let p = HardwareReader.port(id: "x", properties: ["ConnectionActive": false, "ActiveCable": true, "OpticalCable": true, "HPDAsserted": true, "TransportsActive": ["USB3"], "PlugOrientation": 1])
        XCTAssertNil(p.activeCable); XCTAssertNil(p.opticalCable); XCTAssertNil(p.orientation); XCTAssertNil(p.displayActive); XCTAssertTrue(p.activeTransports.isEmpty)
        let power = HardwareReader.parsePower(["ExternalConnected": false, "AdapterDetails": ["Watts": 45], "PowerTelemetryData": ["SystemPowerIn": 43000]])
        XCTAssertNil(power.inputWatts); XCTAssertNil(power.adapterWatts)
    }
    func testMissingIsNotFalseOrZero() {
        let p = HardwareReader.port(id: "x", properties: [:]); XCTAssertNil(p.connected); XCTAssertNil(p.activeCable)
        let power = HardwareReader.parsePower([:]); XCTAssertNil(power.externalConnected); XCTAssertNil(power.batteryPercent); XCTAssertNil(power.inputWatts)
    }
    func testBatterySidePowerMustNotBeShownAsUSBInput() {
        let p = HardwareReader.parsePower(["ExternalConnected": true, "Voltage": 12000, "Amperage": 2000])
        XCTAssertNil(p.inputWatts); XCTAssertNil(p.negotiatedVolts)
    }
    func testMalformedPowerIsRejected() {
        let p = HardwareReader.parsePower(["ExternalConnected": true, "AdapterDetails": ["Watts": true, "Current": -1], "PowerTelemetryData": ["SystemPowerIn": -1000], "MaxCapacity": 0, "CurrentCapacity": 30])
        XCTAssertNil(p.inputWatts); XCTAssertNil(p.adapterWatts); XCTAssertNil(p.negotiatedAmps); XCTAssertNil(p.batteryPercent)
    }
    func testReportOmitsAmbientMachineAndDeviceSerials() throws {
        let s = HardwareReader.snapshot()
        let data = try s.json()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(object["ports"]); XCTAssertNotNil(object["timestamp"])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("IOPlatformUUID")); XCTAssertFalse(text.contains("SerialNumber"))
    }
}
