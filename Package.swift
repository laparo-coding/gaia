// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "Gaia",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .library(name: "GaiaCore", targets: ["GaiaCore"]),
    .library(name: "GaiaFeatureCatalog", targets: ["GaiaFeatureCatalog"]),
    .executable(name: "GaiaCLI", targets: ["GaiaCLI"]),
    .executable(name: "GaiaAuthenticationApp", targets: ["GaiaAuthenticationApp"]),
    .executable(name: "GaiaControllerApp", targets: ["GaiaControllerApp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/rollbar/rollbar-apple", from: "3.4.0")
  ],
  targets: [
    .target(
      name: "GaiaCore",
      dependencies: [
        .product(name: "RollbarNotifier", package: "rollbar-apple")
      ]
    ),
    .target(
      name: "GaiaFeatureCatalog",
      dependencies: ["GaiaCore"]
    ),
    .executableTarget(
      name: "GaiaCLI",
      dependencies: [
        "GaiaCore",
        "GaiaFeatureCatalog",
      ]
    ),
    .executableTarget(
      name: "GaiaAuthenticationApp",
      dependencies: ["GaiaCore"],
      path: "app/authentication",
      exclude: [
        "session/route.swift",
        "sign-in/route.swift",
        "service/hemera/route.swift",
        "service/aither/route.swift",
      ]
    ),
    .executableTarget(
      name: "GaiaControllerApp",
      dependencies: ["GaiaCore"],
      path: "app/controller",
      exclude: [
        "README.md"
      ]
    ),
    .testTarget(
      name: "GaiaCoreTests",
      dependencies: ["GaiaCore"]
    ),
    .testTarget(
      name: "GaiaFeatureCatalogTests",
      dependencies: ["GaiaFeatureCatalog"]
    ),
  ]
)
