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
            dependencies: ["CJanet"],
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "CJanetTests",
            dependencies: ["CJanet"],
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "JanetTests",
            dependencies: ["Janet"],
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        // Runs only via Benchmark/run.sh; see Benchmark/README.md.
        .testTarget(
            name: "JanetBenchmarks",
            dependencies: ["Janet"],
            path: "Benchmark/Sources",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
