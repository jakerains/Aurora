// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AuroraStudio",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "AuroraStudio", targets: ["AuroraStudioApp"])
    ],
    targets: [
        .executableTarget(
            name: "AuroraStudioApp",
            path: "Sources/AuroraStudioApp",
            resources: [
                .copy("Resources/popular_models.json"),
                .copy("Resources/curated_image_models.json"),
                .copy("Resources/AppIcon.icns")
            ]
        ),
        .testTarget(
            name: "AuroraStudioAppTests",
            dependencies: ["AuroraStudioApp"],
            path: "Tests/AuroraStudioAppTests"
        )
    ]
)
