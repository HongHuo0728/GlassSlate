// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GlassSlateCore",
    platforms: [.macOS(.v26)],
    products: [.library(name: "SlateCore", targets: ["SlateCore"])],
    targets: [
        .target(name: "SlateCore", path: "GlassSlate", exclude: ["App", "Views", "Services", "Resources", "Assets.xcassets", "Info.plist", "GlassSlate.icon"], sources: ["Models", "Persistence"]),
        .testTarget(name: "SlateCoreTests", dependencies: ["SlateCore"], path: "GlassSlateTests")
    ]
)
