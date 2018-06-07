// swift-tools-version:4.0
import PackageDescription

var package = Package(
    name: "SignalBox",
    targets: [
        .target(name: "Util"),
        .testTarget(name: "UtilTests", dependencies: ["Util"]),

        .target(name: "RaspberryPi", dependencies: ["Util"]),
        .testTarget(name: "RaspberryPiTests", dependencies: ["RaspberryPi"]),

        .target(name: "DCC", dependencies: ["Util"]),
        .testTarget(name: "DCCTests", dependencies: ["DCC"]),

        .target(name: "OldRaspberryPi"),
        .target(name: "OldDCC", dependencies: ["OldRaspberryPi"]),
        .target(name: "OldPrototype", dependencies: ["OldRaspberryPi", "OldDCC"]),
        ]
)

#if os(Linux)
package.dependencies.append(.package(url: "https://github.com/mdaxter/CBSD", from: "1.0.0"))
#endif
