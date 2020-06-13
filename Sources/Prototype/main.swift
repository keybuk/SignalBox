//
//  main.swift
//  Prototype
//
//  Created by Scott James Remnant on 6/10/20.
//

import Foundation

import DCC

var address: Address = .primary(3)
var dispatcher = Dispatcher()

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
    case "info":
        guard let decoder = dispatcher.decoders[address] else {
            print("Not dispatched")
            break
        }

        print("Address: \(decoder.address)")
        print("Speed:   \(decoder.speed)")
    case "speed":
        guard args.count >= 2,
            let value = Int(args[1])
            else {
                print("Usage: speed SPEED")
                break
        }

        dispatcher.decoders[address, default: Decoder(address: address)]
            .speed = value
    case "stop":
        dispatcher.decoders[address, default: Decoder(address: address)]
            .stop()
    default:
        print("Unknown command.")
        print("Commands: exit quit decoder speed stop")
    }
}
