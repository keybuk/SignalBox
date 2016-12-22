import PackageDescription

let package = Package(
    name: "SignalBox",
    targets: [
        Target(name: "RaspberryPi", dependencies: ["Cmailbox"]),
        Target(name: "Prototype", dependencies: ["RaspberryPi"]),
        Target(name: "TestApp", dependencies: ["RaspberryPi"])
    ]
)
