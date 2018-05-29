// swift-tools-version:4.0
import PackageDescription

var package = Package(
    name: "SignalBox",
    targets: [
        .target(name: "DCC"),
        .testTarget(name: "DCCTests", dependencies: ["DCC"]),

        /*.target(name: "RaspberryPi")*/
    ]
)

#if os(Linux)
package.dependencies.append(.package(url: "https://github.com/mdaxter/CBSD", from: "1.0.0"))
#endif
