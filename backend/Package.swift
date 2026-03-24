// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SQLXBackend",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.9.0")
    ],
    targets: [
        .executableTarget(name: "Run", dependencies: [
            .target(name: "App")
        ]),
        .target(name: "App", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "JWTKit", package: "jwt-kit")
        ]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor")
        ])
    ]
)
