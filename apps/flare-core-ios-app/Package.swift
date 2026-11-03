// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlareImApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FlareImApp", targets: ["FlareImApp"]),
        .executable(name: "FlareImAppRunner", targets: ["FlareImAppRunner"]),
    ],
    dependencies: [
        .package(path: "../../packages/flare-core-apple-sdk"),
        .package(path: "../../../flare-im-design/packages/ios-im-ui"),
    ],
    targets: [
        .target(
            name: "FlareImApp",
            dependencies: [
                .product(name: "FlareCoreAppleSDK", package: "flare-core-apple-sdk"),
                .product(name: "FlareIMUI", package: "ios-im-ui"),
            ],
            path: "Sources/FlareImApp"
        ),
        .executableTarget(
            name: "FlareImAppRunner",
            dependencies: ["FlareImApp"],
            path: "Sources/FlareImAppRunner",
            resources: [.process("Localizable.xcstrings")]
        ),
        .testTarget(
            name: "FlareImAppTests",
            dependencies: [
                "FlareImApp",
                .product(name: "FlareCoreAppleSDK", package: "flare-core-apple-sdk"),
            ],
            path: "Tests/FlareImAppTests"
        ),
    ]
)
