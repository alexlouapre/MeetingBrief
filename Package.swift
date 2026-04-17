// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MeetingBrief",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MeetingBrief",
            path: "Sources/MeetingBrief"
        )
    ]
)
