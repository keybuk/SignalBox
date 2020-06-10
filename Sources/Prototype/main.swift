//
//  main.swift
//  Prototype
//
//  Created by Scott James Remnant on 6/10/20.
//

import Foundation

import DCC

var address: Address = .primary(3)

loop: while true {
    print("\(address)> ", terminator: "")
    guard let line = readLine(strippingNewline: true) else { print(); break }

    let args = line.split(separator: " ")
    switch args[0] {
    case "exit", "quit":
        break loop
    case "decoder":
        guard args.count >= 2,
            let value = Int(args[1])
            else {
                print("Usage: decoder ADDRESS")
                break
        }

        if args[1].starts(with: "0") {
            address = .extended(value)
        } else {
            address = .primary(value)
        }
    default:
        print("Unknown command.")
        print("Commands: exit quit decoder")
    }
}
