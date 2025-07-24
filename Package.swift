// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ezcli",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "ez", targets: ["ezcli"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.6.1")
    ],
    targets: [
        .executableTarget(
            name: "ezcli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "ezcli"
        ),
        .testTarget(
            name: "ezcliTests",
            dependencies: ["ezcli"],
            path: "test",
            swiftSettings: [
                .define("UNIT_TEST")
            ]
        )
    ]
) 