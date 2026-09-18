// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Janet",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Janet", targets: ["Janet"]),
        .library(name: "CJanet", targets: ["CJanet"]),
    ],
    targets: [
        // Vendored Janet amalgamation; regenerate with Scripts/vendor-janet.sh.
        .target(
            name: "CJanet",
            exclude: ["LICENSE", "VERSION"],
            linkerSettings: [
                .linkedLibrary("m", .when(platforms: [.linux])),
                .linkedLibrary("dl", .when(platforms: [.linux])),
                .linkedLibrary("pthread", .when(platforms: [.linux])),
            ]
        ),
        .target(
            name: "Janet",
            dependencies: ["CJanet"]
        ),
        .testTarget(
            name: "JanetTests",
            dependencies: ["Janet"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
