import SwiftUI
import AppKit
import OpenCableCore

/// Produces a local, offscreen view artifact using a real hardware snapshot.
/// Does not capture the desktop, other applications, or synthetic measurements.
@MainActor enum PreviewRenderer {
    static func write(to path: String, store existing: AppStore? = nil) {
        let store = existing ?? AppStore()
        store.paused = true
        store.busy = false
        if store.snapshot == nil { store.snapshot = HardwareReader.snapshot() }
        let view = Dashboard(store: store).environment(\.colorScheme, .light)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 820, height: 1320)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fputs("Cannot create preview bitmap\n", stderr); exit(1) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
        do { try png.write(to: URL(fileURLWithPath: path), options: .atomic) } catch { fputs("\(error)\n", stderr); exit(1) }
        print("Preview written: \(path)")
    }
}
