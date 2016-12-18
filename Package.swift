import PackageDescription

let package = Package(
    name: "SignalBox",
    targets: [
        Target(name: "TestApp", dependencies: ["Cmailbox"])
    ]
)
