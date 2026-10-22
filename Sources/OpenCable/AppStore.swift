import Foundation
import SwiftUI
import AppKit
import OpenCableCore

struct PowerPoint: Identifiable {
    let id = UUID()
    let time: Date
    let watts: Double
}
@MainActor final class AppStore: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var samples: [PowerPoint] = []
    @Published var events: [String] = []
    @Published var busy = false
    @Published var errorMessage: String?
    @Published var paused = false
    private var timer: Timer?
    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in guard let self, !self.paused else { return }; self.refresh() }
        }
    }
    func refresh() {
        guard !busy else { return }
        busy = true
        DispatchQueue.global(qos: .utility).async {
            let next = HardwareReader.snapshot()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let previous = self.snapshot {
                    for port in next.ports {
                        if let old = previous.ports.first(where: { $0.id == port.id }), old.connected != port.connected || old.activeTransports != port.activeTransports {
                            self.event("端口 \(port.number.map(String.init) ?? "?")：\(port.connected == true ? "已连接" : port.connected == false ? "已断开" : "状态未知") · \(port.activeTransports.joined(separator: ", "))")
                        }
                    }
                    for removed in previous.ports where !next.ports.contains(where: { $0.id == removed.id }) { self.event("端口控制器 \(removed.number.map(String.init) ?? "?") 不再可读") }
                    if previous.power.externalConnected != next.power.externalConnected {
                        self.event(next.power.externalConnected == true ? "接入外部电源" : "外部电源断开或不可读")
                    }
                    let oldIDs = Set(previous.usbDevices.map(\.id)), newIDs = Set(next.usbDevices.map(\.id))
                    for device in next.usbDevices where !oldIDs.contains(device.id) { self.event("USB 接入：\(device.name)") }
                    for device in previous.usbDevices where !newIDs.contains(device.id) { self.event("USB 移除：\(device.name)") }
                }
                if let watts = next.power.inputWatts { self.samples.append(PowerPoint(time: next.timestamp, watts: watts)) }
                let cutoff = Date().addingTimeInterval(-600)
                self.samples.removeAll { $0.time < cutoff }
                self.snapshot = next
                self.busy = false
            }
        }
    }
    private func event(_ text: String) {
        events.insert("\(Date().formatted(date: .omitted, time: .standard))  \(text)", at: 0)
        if events.count > 100 { events.removeLast(events.count - 100) }
    }
    func exportReport() {
        guard let snapshot else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "OpenCable-报告.json"
        panel.message = "报告仅保存到你选择的位置，含设备名称和硬件型号标识；不会上传。"
        if panel.runModal() == .OK, let url = panel.url {
            do { try snapshot.json().write(to: url, options: .atomic); errorMessage = nil } catch { errorMessage = error.localizedDescription }
        }
    }
    func copyReport() {
        guard let snapshot else { return }
        do {
            let text = String(decoding: try snapshot.json(), as: UTF8.self)
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
