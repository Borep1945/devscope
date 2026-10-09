// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "DevScope",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "DevScope", targets: ["DevScope"]), .library(name: "DevScopeCore", targets: ["DevScopeCore"])],
    targets: [.target(name: "DevScopeCore"), .executableTarget(name: "DevScope", dependencies: ["DevScopeCore"]), .testTarget(name: "DevScopeCoreTests", dependencies: ["DevScopeCore"])]
)
