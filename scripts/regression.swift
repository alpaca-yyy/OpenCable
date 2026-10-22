import Foundation

@main
struct Regression {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError("FAIL: \(message)") }
    }
    static func close(_ value: Double?, _ expected: Double, _ message: String) {
        expect(value.map { abs($0 - expected) < 0.000001 } == true, message)
    }
    static func main() throws {
        let fixture: [String: Any] = [
            "ExternalConnected": true, "IsCharging": true,
            "AdapterDetails": ["Watts": 45, "AdapterVoltage": 20000, "Current": 2250,
                "UsbHvcMenu": [["MaxVoltage": 5000, "MaxCurrent": 3000], ["MaxVoltage": 20000, "MaxCurrent": 2250]]],
            "PowerTelemetryData": ["SystemPowerIn": 43462], "CurrentCapacity": 60, "MaxCapacity": 100,
            "Serial": "TEST-BATTERY-SERIAL-PRIVATE", "IOPlatformUUID": "TEST-PLATFORM-UUID-PRIVATE"
        ]
        let power = HardwareReader.parsePower(fixture)
        close(power.adapterWatts, 45, "adapter rated watts")
        close(power.negotiatedVolts, 20, "adapter mV converted to V")
        close(power.negotiatedAmps, 2.25, "adapter mA converted to A")
        close(power.inputWatts, 43.462, "telemetry mW converted to W")
        close(power.batteryPercent, 60, "battery percent")
        expect(power.profiles.count == 2, "valid profile count")
        expect(power.profiles.map(\.volts) == [5, 20], "MaxVoltage profile field and units")
        expect(power.profiles.map(\.amps) == [3, 2.25], "MaxCurrent profile field and units")
        expect(power.profiles.map(\.watts) == [15, 45], "profile watt calculation")

        let portFixture: [String: Any] = ["PortNumber": 1, "ConnectionActive": false,
            "TransportsActive": ["USB3"], "TransportsSupported": ["CC", "USB3"],
            "PlugOrientation": 1, "ActiveCable": true, "OpticalCable": true, "HPDAsserted": true,
            "IOAccessoryUSBConnectString": "stale", "SerialNumber": "TEST-CABLE-SERIAL-PRIVATE"]
        let port = HardwareReader.port(id: "test-port", properties: portFixture)
        expect(port.connected == false, "explicit disconnected state")
        expect(port.activeTransports.isEmpty, "disconnect clears stale transports")
        expect(port.orientation == nil && port.activeCable == nil && port.opticalCable == nil && port.displayActive == nil && port.connectionDescription == nil, "disconnect clears cable observations")
        expect(port.supportedTransports == ["CC", "USB3"], "disconnect preserves host capabilities")
        var disconnectedFixture = fixture
        disconnectedFixture["ExternalConnected"] = false
        let disconnected = HardwareReader.parsePower(disconnectedFixture)
        expect(disconnected.inputWatts == nil && disconnected.adapterWatts == nil && disconnected.negotiatedVolts == nil && disconnected.negotiatedAmps == nil && disconnected.profiles.isEmpty, "disconnect clears stale adapter values")

        let missing = HardwareReader.parsePower([:])
        expect(missing.externalConnected == nil && missing.charging == nil && missing.batteryPercent == nil && missing.inputWatts == nil && missing.adapterWatts == nil, "missing data is unknown")
        let missingPort = HardwareReader.port(id: "unknown", properties: [:])
        expect(missingPort.connected == nil && missingPort.number == nil && missingPort.activeCable == nil && missingPort.displayActive == nil, "missing port state is unknown")
        let batteryOnly = HardwareReader.parsePower(["ExternalConnected": true, "Voltage": 12000, "Amperage": 2000, "BatteryData": ["SystemPower": 24000]])
        expect(batteryOnly.inputWatts == nil && batteryOnly.negotiatedVolts == nil, "battery-side data never substitutes USB input")

        for bad: Any in [-1000, NSNumber(value: true), Double.nan, Double.infinity] {
            let malformed = HardwareReader.parsePower(["ExternalConnected": true, "AdapterDetails": ["Watts": bad, "Current": bad, "AdapterVoltage": bad, "UsbHvcMenu": [["MaxVoltage": bad, "MaxCurrent": 3000], ["MaxVoltage": 5000, "MaxCurrent": bad]]], "PowerTelemetryData": ["SystemPowerIn": bad]])
            expect(malformed.inputWatts == nil && malformed.adapterWatts == nil && malformed.negotiatedVolts == nil && malformed.negotiatedAmps == nil && malformed.profiles.isEmpty, "reject malformed power \(bad)")
            expect(HardwareReader.integer(bad) == nil, "reject malformed integer \(bad)")
        }
        let zeroInput = HardwareReader.parsePower(["ExternalConnected": true, "PowerTelemetryData": ["SystemPowerIn": 0]])
        close(zeroInput.inputWatts, 0, "valid explicit zero differs from unknown")
        expect(HardwareReader.boolean(2) == nil && HardwareReader.boolean(-1) == nil, "reject non-boolean state")

        let report = Snapshot(timestamp: Date(timeIntervalSince1970: 0), ports: [port], power: power, usbDevices: [], warnings: [])
        try verifyReport(report, privateValues: ["TEST-BATTERY-SERIAL-PRIVATE", "TEST-CABLE-SERIAL-PRIVATE", "TEST-PLATFORM-UUID-PRIVATE"])
        try verifyReport(HardwareReader.snapshot(), privateValues: [])
        print("PASS: \(checks) regression checks; fixture parsing and live JSON report verified.")
    }
    static func verifyReport(_ report: Snapshot, privateValues: [String]) throws {
        let data = try report.json()
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        expect(object?["ports"] != nil && object?["power"] != nil && object?["timestamp"] != nil, "JSON report structural validity")
        _ = try JSONDecoder.withISODate.decode(Snapshot.self, from: data)
        let text = String(decoding: data, as: UTF8.self)
        expect(!text.lowercased().contains("serial"), "report omits serial fields")
        expect(!text.contains("IOPlatformUUID"), "report omits platform UUID")
        for value in privateValues { expect(!text.contains(value), "report excludes injected private value") }
    }
}
private extension JSONDecoder {
    static var withISODate: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}
