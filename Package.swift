import PackageDescription

let package = Package(
    name: "SignalBox",
    targets: [
        Target(name: "RaspberryPi"),
        Target(name: "DCC", dependencies: ["RaspberryPi"]),
        Target(name: "Prototype", dependencies: ["RaspberryPi", "DCC"]),
    ]
)
