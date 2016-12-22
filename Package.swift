import PackageDescription

let package = Package(
    name: "SignalBox",
    targets: [
        Target(name: "Mailbox", dependencies: ["Cmailbox"]),
        Target(name: "Prototype", dependencies: ["Mailbox"]),
        Target(name: "TestApp", dependencies: ["Mailbox"])
    ]
)
