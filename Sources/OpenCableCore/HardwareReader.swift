import Foundation
import IOKit
import CoreFoundation

/// Read-only IORegistry access. No IOConnect calls, writes, shell commands, or networking.
public enum HardwareReader {
    public static func properties(_ className: String) -> [(String, [String: Any])] {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching(className),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [(String, [String: Any])] = []
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }
            var raw: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &raw, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = raw?.takeRetainedValue() as? [String: Any] else { continue }
            var registryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(entry, &registryID)
            result.append((String(registryID, radix: 16), props))
        }
        return result
    }
    public static func snapshot() -> Snapshot {
        let controllers = properties("AppleTCController")
        let ports = controllers.map { id, p in port(id: id, properties: p) }.sorted {
            ($0.number ?? Int.max, $0.id) < ($1.number ?? Int.max, $1.id)
        }
        let batteries = properties("AppleSmartBattery")
        let power = parsePower(batteries.first?.1 ?? [:])
        let devices = properties("IOUSBHostDevice").map { id, p in
            USBDevice(id: id, name: p["USB Product Name"] as? String ?? "USB 设备", vendorID: integer(p["idVendor"]), productID: integer(p["idProduct"]), speedCode: integer(p["USBSpeed"]), locationID: (p["locationID"] as? NSNumber)?.uint64Value)
        }.sorted { $0.id < $1.id }
        var warnings = ["连接状态不等于线材认证或最大传输速度；本工具不进行吞吐量测试。"]
        if ports.isEmpty { warnings.append("此 Mac 未公开 AppleTCController 信息，不能据此认定没有 Type-C 端口。") }
        if batteries.isEmpty { warnings.append("未读取到 AppleSmartBattery；台式 Mac 或部分机型不提供充电数据。") }
        return Snapshot(timestamp: Date(), ports: ports, power: power, usbDevices: devices, warnings: warnings)
    }
    public static func port(id: String, properties p: [String: Any]) -> Port {
        let connected = boolean(p["ConnectionActive"])
        return Port(id: id, number: integer(p["PortNumber"]), connected: connected,
                    activeTransports: connected == true ? p["TransportsActive"] as? [String] ?? [] : [],
                    supportedTransports: p["TransportsSupported"] as? [String] ?? [],
                    orientation: connected == true ? integer(p["PlugOrientation"]) : nil,
                    activeCable: connected == true ? boolean(p["ActiveCable"]) : nil,
                    opticalCable: connected == true ? boolean(p["OpticalCable"]) : nil,
                    displayActive: connected == true ? boolean(p["HPDAsserted"]) : nil,
                    connectionDescription: connected == true ? p["IOAccessoryUSBConnectString"] as? String : nil)
    }
    public static func parsePower(_ p: [String: Any]) -> Power {
        let external = boolean(p["ExternalConnected"])
        let adapter = p["AdapterDetails"] as? [String: Any] ?? [:]
        let telemetry = p["PowerTelemetryData"] as? [String: Any] ?? [:]
        let current = finiteNumber(p["CurrentCapacity"])
        let maximum = finiteNumber(p["MaxCapacity"])
        let percent = current.flatMap { c in maximum.flatMap { m in m > 0 ? min(100, max(0, c / m * 100)) : nil } }
        let profiles = (adapter["UsbHvcMenu"] as? [[String: Any]] ?? []).compactMap { p -> PowerProfile? in
            guard let v = positive(p["MaxVoltage"]), let a = positive(p["MaxCurrent"]) else { return nil }
            return PowerProfile(volts: v / 1000, amps: a / 1000)
        }
        var warnings = ["充电器报告值与当前输入功率不代表线材的最大额定功率。", "输入功率来自 Apple 未公开遥测字段，按 mW 换算；系统版本或机型变化可能使字段不可用。"]
        let input = external == true ? finiteNumber(telemetry["SystemPowerIn"]).flatMap { $0 >= 0 && $0 < 1_000_000 ? $0 / 1000 : nil } : nil
        if input == nil { warnings.append("本次未获得可用的外部输入功率，不能用电池侧功率替代。") }
        return Power(externalConnected: external, charging: boolean(p["IsCharging"]),
                     adapterWatts: external == true ? positive(adapter["Watts"]) : nil,
                     negotiatedVolts: external == true ? positive(adapter["AdapterVoltage"]).map { $0 / 1000 } : nil,
                     negotiatedAmps: external == true ? positive(adapter["Current"]).map { $0 / 1000 } : nil,
                     inputWatts: input, batteryPercent: percent, profiles: external == true ? profiles : [], warnings: warnings)
    }
    static func finiteNumber(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }
    static func positive(_ value: Any?) -> Double? { finiteNumber(value).flatMap { $0 > 0 ? $0 : nil } }
    static func integer(_ value: Any?) -> Int? { finiteNumber(value).flatMap { $0 >= 0 && $0 < Double(Int.max) ? Int($0) : nil } }
    static func boolean(_ value: Any?) -> Bool? {
        guard let n = value as? NSNumber, n == 0 || n == 1 else { return nil }
        return n.boolValue
    }
}
