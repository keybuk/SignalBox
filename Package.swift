// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SignalBox",
    products: [
        .library(name: "Util", targets: ["RaspberryPi"]),
        .library(name: "RaspberryPi", targets: ["RaspberryPi"]),
        .library(name: "DCC", targets: ["DCC"]),

        .executable(name: "TestGPIO", targets: ["TestGPIO"]),
        .executable(name: "TestPWM", targets: ["TestPWM"]),
        .executable(name: "TestDMA", targets: ["TestDMA"]),
        .executable(name: "TestFIFO", targets: ["TestFIFO"]),
        .executable(name: "TestRaspberryPi", targets: ["TestRaspberryPi"]),

        .executable(name: "DebugDMA", targets: ["DebugDMA"]),
    ],
    targets: [
        .target(name: "Util"),
        .testTarget(name: "UtilTests", dependencies: ["Util"]),

        .target(name: "RaspberryPi", dependencies: ["Util"]),
        .testTarget(name: "RaspberryPiTests", dependencies: ["RaspberryPi"]),

        .target(name: "DCC", dependencies: ["Util"]),
        .testTarget(name: "DCCTests", dependencies: ["DCC"]),

        .target(name: "OldDCC", dependencies: ["Util", "RaspberryPi"]),
        .target(name: "OldPrototype", dependencies: ["OldDCC"]),

        .target(name: "TestGPIO", dependencies: ["RaspberryPi"]),
        .target(name: "TestPWM", dependencies: ["RaspberryPi"]),
        .target(name: "TestDMA", dependencies: ["RaspberryPi"]),
        .target(name: "TestFIFO", dependencies: ["RaspberryPi"]),
        .target(name: "TestRaspberryPi", dependencies: ["RaspberryPi"]),

        .target(name: "DebugDMA", dependencies: ["RaspberryPi"]),
    ]
)
