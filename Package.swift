// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "OpenCable", platforms: [.macOS(.v14)], products: [.executable(name: "OpenCable", targets: ["OpenCable"]), .executable(name: "opencable-cli", targets: ["OpenCableCLI"])], targets: [
    .target(name: "OpenCableCore", linkerSettings: [.linkedFramework("IOKit")]),
    .executableTarget(name: "OpenCable", dependencies: ["OpenCableCore"], linkerSettings: [.linkedFramework("AppKit")]),
    .executableTarget(name: "OpenCableCLI", dependencies: ["OpenCableCore"]),
    .testTarget(name: "OpenCableCoreTests", dependencies: ["OpenCableCore"])
])
