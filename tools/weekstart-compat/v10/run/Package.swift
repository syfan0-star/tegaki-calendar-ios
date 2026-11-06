// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "Probe", platforms: [.macOS(.v14)],
  dependencies: [.package(path: "../TegakiKit")],
  targets: [.executableTarget(name: "Probe", dependencies: [
    .product(name: "InkModel", package: "TegakiKit"), .product(name: "Layout", package: "TegakiKit"), .product(name: "DayKit", package: "TegakiKit")], path: "Sources/Probe")],
  swiftLanguageVersions: [.v5])
