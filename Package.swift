// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MeetingBrief",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "MeetingBrief",
            path: "Sources/MeetingBrief",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
