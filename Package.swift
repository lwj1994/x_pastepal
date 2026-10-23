// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XPastepal",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "XPastepal", targets: ["XPastepal"])],
    dependencies: [
        .package(url: "https://github.com/jaywcjlove/PermissionFlow.git", exact: "2.11.3"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "3.1.0")
    ],
    targets: [
        .target(name: "XPastepalCore"),
        .executableTarget(name: "XPastepal", dependencies: [
            "XPastepalCore",
            .product(name: "PermissionFlow", package: "PermissionFlow"),
            .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
        ]),
        .testTarget(name: "XPastepalCoreTests", dependencies: ["XPastepalCore"]),
        .testTarget(name: "XPastepalTests", dependencies: ["XPastepal"])
    ],
    swiftLanguageModes: [.v5]
)
