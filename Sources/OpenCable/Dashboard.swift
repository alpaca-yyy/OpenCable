import SwiftUI
import Charts
import OpenCableCore

struct Dashboard: View {
    @ObservedObject var store: AppStore
    @AppStorage("hideEmptyPorts") private var hideEmptyPorts = false
    private var ports: [OpenCableCore.Port] {
        (store.snapshot?.ports ?? []).filter { !hideEmptyPorts || $0.connected != false }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.callout)
                }
                HStack(spacing: 12) {
                    metric("实时输入", value: store.snapshot?.power.inputWatts.map { "≈ " + number($0, unit: "W") } ?? "未知", icon: "bolt.fill", color: .orange)
                    metric("已连接端口", value: store.snapshot.map { "\($0.connectedCount) / \($0.ports.count)" } ?? "未知", icon: "cable.connector", color: .teal)
                    metric("USB 设备", value: store.snapshot.map { "\($0.usbDevices.count)" } ?? "未知", icon: "externaldrive.connected.to.line.below", color: .blue)
                }
                powerSection
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Type-C 端口", subtitle: "当前连接与端口能力分别显示")
                    if ports.isEmpty { empty("暂无可显示的端口", icon: "cable.connector") }
                    ForEach(ports) { port in portCard(port) }
                }
                usbSection
                eventSection
                settings
                Text("本机只读检测 · 所有数据保留在你的 Mac。线材最大功率、最大速率及认证状态需要额外证据，当前连接无法完整证明。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 680, minHeight: 560)
    }
    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "cable.connector").font(.system(size: 26, weight: .semibold)).foregroundStyle(.teal)
                .frame(width: 48, height: 48).background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("OpenCable").font(.system(size: 27, weight: .bold, design: .rounded))
                Text("免费开源 · 本机检测").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if store.busy { ProgressView().controlSize(.small) }
            Button(action: { store.refresh() }) { Image(systemName: "arrow.clockwise") }.help("立即刷新")
            Button("导出 JSON", action: { store.exportReport() })
            Button(action: { store.copyReport() }) { Image(systemName: "doc.on.doc") }.help("复制报告")
        }
    }
    private func metric(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.callout).foregroundStyle(color)
            Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
    private var powerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("供电概览", subtitle: "输入功率来自系统遥测，可能因机型而缺失")
                Spacer()
                Text(store.snapshot?.power.charging.map { $0 ? "正在充电" : "未充电" } ?? "状态未知")
                    .font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(.teal.opacity(0.1), in: Capsule())
            }
            HStack(spacing: 24) {
                detail("充电器报告功率", number(store.snapshot?.power.adapterWatts, unit: "W"))
                detail("系统报告电压", number(store.snapshot?.power.negotiatedVolts, unit: "V"))
                detail("系统报告电流", number(store.snapshot?.power.negotiatedAmps, unit: "A"))
                detail("电池", number(store.snapshot?.power.batteryPercent, unit: "%", digits: 0))
            }
            if store.samples.count > 1 {
                Chart(store.samples) { sample in
                    AreaMark(x: .value("时间", sample.time), y: .value("输入功率", sample.watts))
                        .foregroundStyle(LinearGradient(colors: [.teal.opacity(0.22), .teal.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("时间", sample.time), y: .value("输入功率", sample.watts)).foregroundStyle(.teal).lineStyle(StrokeStyle(lineWidth: 2))
                }.chartYAxisLabel("W").chartYScale(domain: .automatic(includesZero: true)).frame(height: 125)
            } else {
                empty("等待更多输入功率采样…", icon: "waveform.path.ecg").frame(height: 85)
            }
            if let profiles = store.snapshot?.power.profiles, !profiles.isEmpty {
                Text("电源可供档位 · " + profiles.map { String(format: "%.0fV / %.2fA", $0.volts, $0.amps) }.joined(separator: "   "))
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            DisclosureGroup("读数说明") {
                if let warnings = store.snapshot?.power.warnings { ForEach(warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) } }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(18).background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
    private func portCard(_ port: OpenCableCore.Port) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(port.connected == true ? Color.teal : Color.secondary.opacity(0.4)).frame(width: 8, height: 8)
                Text(port.number.map { "USB-C 端口 \($0)" } ?? "USB-C 端口").font(.headline)
                Spacer()
                Text(port.connected.map { $0 ? "已连接" : "未连接" } ?? "状态未知").font(.callout).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 20) {
                detail("当前活跃协议", port.activeTransports.isEmpty ? (port.connected == false ? "无连接" : "未知") : port.activeTransports.joined(separator: " · "))
                detail("端口支持协议", port.supportedTransports.isEmpty ? "未知" : port.supportedTransports.joined(separator: " · "))
            }
            if port.connected == true {
                HStack(spacing: 20) {
                    detail("有源线标记", flag(port.activeCable))
                    detail("光纤线标记", flag(port.opticalCable))
                    detail("显示信号", flag(port.displayActive))
                }
            }
        }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
    private var usbSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("USB 设备", subtitle: "枚举设备不代表已测试线材最高速率")
            if let devices = store.snapshot?.usbDevices, !devices.isEmpty {
                ForEach(devices) { device in
                    HStack {
                        Image(systemName: "externaldrive").foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.name).font(.callout.weight(.medium))
                            Text("VID \(hex(device.vendorID)) · PID \(hex(device.productID))").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(device.speedCode.map { "系统速率代码 \($0)" } ?? "速率未知").font(.caption).foregroundStyle(.secondary)
                    }
                    if device.id != devices.last?.id { Divider() }
                }
            } else { empty(store.snapshot == nil ? "等待检测" : "未发现 USB 数据设备", icon: "externaldrive") }
        }.padding(18).background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("连接动态", subtitle: "本次运行期间的变化")
            if store.events.isEmpty { Text("尚无连接变化").font(.callout).foregroundStyle(.secondary) }
            ForEach(Array(store.events.prefix(12).enumerated()), id: \.offset) { _, event in
                Label(event, systemImage: "circle.fill").font(.caption).foregroundStyle(.secondary)
            }
            if let warnings = store.snapshot?.warnings { ForEach(warnings, id: \.self) { Label($0, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary) } }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
    private var settings: some View {
        HStack(spacing: 20) {
            Toggle("隐藏未连接端口", isOn: $hideEmptyPorts)
            Toggle("暂停采样", isOn: $store.paused)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("每 5 秒自动刷新").font(.caption).foregroundStyle(.secondary)
                if let time = store.snapshot?.timestamp { Text(time, style: .time).font(.caption2).foregroundStyle(.tertiary) }
            }
        }.toggleStyle(.checkbox).font(.callout)
    }
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
    }
    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(label).font(.caption).foregroundStyle(.secondary); Text(value).font(.callout.weight(.medium)).textSelection(.enabled) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func empty(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 10)
    }
    private func number(_ value: Double?, unit: String, digits: Int = 1) -> String {
        guard let value, value.isFinite else { return "未知" }; return String(format: "%.*f %@", digits, value, unit)
    }
    private func flag(_ value: Bool?) -> String { value.map { $0 ? "是" : "否" } ?? "未知" }
    private func hex(_ value: Int?) -> String { value.map { String(format: "%04X", $0) } ?? "未知" }
}
