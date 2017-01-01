import PackageDescription

var package = Package(
    name: "SignalBox",
    targets: [
        Target(name: "RaspberryPi"),
        Target(name: "DCC", dependencies: ["RaspberryPi"]),
        Target(name: "Prototype", dependencies: ["RaspberryPi", "DCC"]),
    ]
)

#if os(Linux)
package.dependencies.append(.Package(url: "https://github.com/mdaxter/CBSD", majorVersion: 1))
#endif
