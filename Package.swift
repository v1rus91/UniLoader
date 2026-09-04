// swift-tools-version:5.9
import PackageDescription

// Command Line Tools не додають шлях до Testing.framework автоматично — вказуємо явно (Xcode робить це сам).
let fw = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let lib = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

let package = Package(
    name: "UniLoader",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "UniLoader", path: "Sources/UniLoader"),
        .testTarget(
            name: "UniLoaderTests",
            dependencies: ["UniLoader"],
            path: "Tests/UniLoaderTests",
            swiftSettings: [.unsafeFlags(["-F", fw])],
            linkerSettings: [.unsafeFlags(["-F", fw, "-L", lib, "-Xlinker", "-rpath", "-Xlinker", fw, "-Xlinker", "-rpath", "-Xlinker", lib])]
        ),
    ]
)
