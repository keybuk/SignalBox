// swift-tools-version:4.0
import PackageDescription

var package = Package(
    name: "SignalBox",
    targets: [
        .target(name: "RaspberryPi"),
        .target(name: "DCC", dependencies: ["RaspberryPi"]),
        .target(name: "Prototype", dependencies: ["RaspberryPi", "DCC"]),
    ]
)

#if os(Linux)
package.dependencies.append(.package(url: "https://github.com/mdaxter/CBSD", from: "1.0.0"))
#endif
