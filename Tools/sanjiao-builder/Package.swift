// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sanjiao-builder",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../Packages/SanJiaoCore")
    ],
    targets: [
        .executableTarget(name: "SanJiaoBuilder", dependencies: ["SanJiaoCore"]),
        .testTarget(name: "SanJiaoBuilderTests", dependencies: ["SanJiaoBuilder"],
                    resources: [.copy("Fixtures")]),
    ]
)
