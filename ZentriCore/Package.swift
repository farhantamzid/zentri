// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZentriCore",
    platforms: [
        // Swift 6.0 tools version predates the `.v27` package-description cases,
        // so the equivalent version strings are used.
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "ZentriCore", targets: ["ZentriCore"]),
    ],
    targets: [
        .target(name: "ZentriCore"),
        .testTarget(name: "ZentriCoreTests", dependencies: ["ZentriCore"]),
    ],
    swiftLanguageModes: [.v6]
)
