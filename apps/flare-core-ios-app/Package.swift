// swift-tools-version: 5.9
import Foundation
import PackageDescription

// The Kit follows the switch of flare-core-apple-update-ui, which depends on it too: two sources of one package
// would link two FlareIMUI. A path dependency's package name is its directory name, a url's the repository's.
let usePublishedKit = ProcessInfo.processInfo.environment["FLARE_USE_PUBLISHED_KIT"] == "true"

let kitDependency: Package.Dependency = usePublishedKit
    ? .package(url: "https://github.com/flare-im/flare-im-design.git", from: "1.0.9")
    : .package(path: "../../../flare-im-design/packages/ios-im-ui")

let kitPackageName = usePublishedKit ? "flare-im-design" : "ios-im-ui"

let package = Package(
    name: "FlareImApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FlareImApp", targets: ["FlareImApp"]),
        .executable(name: "FlareImAppRunner", targets: ["FlareImAppRunner"]),
    ],
    dependencies: [
        .package(path: "../../../flare-core-sdk/packages/flare-core-apple-sdk"),
        .package(path: "../../../flare-core-sdk/packages/flare-core-apple-update-ui"),
        kitDependency,
    ],
    targets: [
        .target(
            name: "FlareImApp",
            dependencies: [
                .product(name: "FlareCoreAppleSDK", package: "flare-core-apple-sdk"),
                .product(name: "FlarePlatformUpdate", package: "flare-core-apple-sdk"),
                .product(name: "FlareUpdateUI", package: "flare-core-apple-update-ui"),
                .product(name: "FlareIMUI", package: kitPackageName),
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
