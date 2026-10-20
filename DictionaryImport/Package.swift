// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DictionaryImport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DictionaryImport", targets: ["DictionaryImport"])],
    targets: [
        .target(name: "DictionaryImport"),
        .testTarget(name: "DictionaryImportTests", dependencies: ["DictionaryImport"])
    ]
)
