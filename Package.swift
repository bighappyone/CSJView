// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CSJView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CSJView",
            targets: ["CSJView"]
        ),
    ],
    dependencies: [
        // Ads-CN 需要通过 CocoaPods 管理，这里不添加
    ],
    targets: [
        .target(
            name: "CSJView",
            dependencies: [],
            path: "Sources"
        ),
    ]
)

