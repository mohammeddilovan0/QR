// swift-tools-version: 5.9
import PackageDescription

// Uygulamanın imza (provisioning profile) bitiş tarihini web tarafına veren küçük eklenti.
let package = Package(
    name: "KisiselImza",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "KisiselImza", targets: ["ImzaPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "ImzaPlugin",
            dependencies: [.product(name: "Capacitor", package: "capacitor-swift-pm")],
            path: "Sources/ImzaPlugin")
    ]
)
