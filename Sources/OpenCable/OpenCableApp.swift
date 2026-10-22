import SwiftUI
import AppKit
import OpenCableCore

@main @MainActor struct OpenCableApp: App {
    init() {
        if let i = CommandLine.arguments.firstIndex(of: "--self-check"), CommandLine.arguments.count > i + 1 {
            let checkStore = AppStore()
            RunLoop.main.run(until: Date().addingTimeInterval(11))
            guard checkStore.snapshot != nil, !checkStore.busy else { fputs("Live refresh failed\n", stderr); exit(1) }
            if checkStore.snapshot?.power.inputWatts != nil && checkStore.samples.count < 2 { fputs("Power history failed\n", stderr); exit(1) }
            PreviewRenderer.write(to: CommandLine.arguments[i + 1], store: checkStore)
            print("PASS: live refresh, timer and preview; samples=\(checkStore.samples.count)")
            exit(0)
        }
        if let i = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > i + 1 {
            PreviewRenderer.write(to: CommandLine.arguments[i + 1])
            exit(0)
        }
    }
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup("OpenCable · 线缆与充电", id: "dashboard") {
            Dashboard(store: store).frame(minWidth: 720, minHeight: 650)
        }.defaultSize(width: 800, height: 780)
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            Image(systemName: "cable.connector")
            if let w = store.snapshot?.power.inputWatts { Text(String(format: "%.0f W", w)) }
        }
    }
}
private struct MenuContent: View {
    @ObservedObject var store: AppStore
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Text("OpenCable · 免费开源")
        if let s = store.snapshot {
            Text("连接端口 \(s.connectedCount) / \(s.ports.count) · USB 设备 \(s.usbDevices.count)")
            if let watts = s.power.inputWatts { Text(String(format: "当前系统输入约 %.1f W", watts)) }
        }
        Button("打开检测面板") { openWindow(id: "dashboard"); NSApp.activate(ignoringOtherApps: true) }
        Button("刷新") { store.refresh() }
        Button("复制 JSON 报告") { store.copyReport() }
        Toggle("暂停采样", isOn: $store.paused)
        Divider()
        Button("退出 OpenCable") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
