// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HiramekiWhiteboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HiramekiWhiteboard", targets: ["HiramekiWhiteboard"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HiramekiWhiteboard",
            path: "Sources"
        )
    ]
)
