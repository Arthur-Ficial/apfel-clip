// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "apfel-clip",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "apfel-clip",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ])
            ]
        ),
    ]
)
