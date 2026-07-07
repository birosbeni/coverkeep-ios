// swift-tools-version: 6.0
// WarrantyRules — Coverkeep's pure rules engine: country rule sets as
// versioned, bundled JSON plus deadline computation. Zero UI imports; the
// macOS floor exists only so the exhaustive unit tests run on the Mac.
import PackageDescription

let package = Package(
    name: "WarrantyRules",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WarrantyRules", targets: ["WarrantyRules"])
    ],
    targets: [
        .target(
            name: "WarrantyRules",
            resources: [.copy("Rules")]
        ),
        .testTarget(
            name: "WarrantyRulesTests",
            dependencies: ["WarrantyRules"]
        ),
    ]
)
