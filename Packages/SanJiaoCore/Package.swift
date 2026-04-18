// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SanJiaoCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SanJiaoCore", targets: ["SanJiaoCore"]),
    ],
    targets: [
        .target(name: "SanJiaoCore"),
        .testTarget(name: "SanJiaoCoreTests", dependencies: ["SanJiaoCore"],
                    resources: [.copy("Fixtures")]),
    ]
)
