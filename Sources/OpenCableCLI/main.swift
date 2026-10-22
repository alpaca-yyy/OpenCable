import Foundation
import OpenCableCore
let arguments = CommandLine.arguments.dropFirst()
if arguments.contains("--help") {
    print("opencable-cli [--json]\nRead local Type-C, USB and power telemetry once. No network, root or external dependencies.")
} else {
    do {
        let snapshot = HardwareReader.snapshot()
        if arguments.contains("--json") { FileHandle.standardOutput.write(try snapshot.json()); print() }
        else {
            print("OpenCable 0.1.0 · \(snapshot.connectedCount)/\(snapshot.ports.count) ports connected · \(snapshot.usbDevices.count) USB devices")
            if let w = snapshot.power.inputWatts { print(String(format: "System input ≈ %.1f W (unpublished Apple telemetry)", w)) }
            for p in snapshot.ports { print("Port \(p.number.map(String.init) ?? "?"): \(p.connected.map { $0 ? "connected" : "disconnected" } ?? "unknown"); active: \(p.activeTransports.joined(separator: ", "))") }
        }
    } catch { fputs("Report encoding failed: \(error)\n", stderr); exit(1) }
}
