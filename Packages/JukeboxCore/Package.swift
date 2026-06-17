// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JukeboxCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "JukeboxCore", targets: ["JukeboxCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox.git", from: "0.26.0")
    ],
    targets: [
        .target(
            name: "JukeboxCore",
            dependencies: [
                .product(name: "FlyingFox", package: "FlyingFox")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
