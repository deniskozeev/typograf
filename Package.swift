// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Typograf",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Typograf", targets: ["TypografApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "TypografApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/TypografApp",
            resources: [
                .copy("Resources/typograf.min.js"),
                .copy("Resources/typograf.titles.json"),
                .copy("Resources/typograf.groups.json"),
                .copy("Resources/Literata.ttf")
            ],
            linkerSettings: [
                // Sparkle.framework кладётся в Contents/Frameworks бандла (см. build.sh).
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
