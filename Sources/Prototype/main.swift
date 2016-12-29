//
//  main.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

import Foundation

import RaspberryPi
import DCC

let resetPacket = Packet(bytes: [0b00000000, 0b00000000, 0b00000000])
let idlePacket  = Packet(bytes: [0b11111111, 0b00000000, 0b11111111])
let startPacket = Packet(bytes: [0b00000011, 0b01111000, 0b01111011])
let stopPacket  = Packet(bytes: [0b00000011, 0b01100000, 0b01100011])

func functionPacket(_ function: Int, value: Bool) -> Packet {
    let loco = 0b00000011
    var command: Int = 0
    switch function {
    case 0:
        command = 0b10010000
    case 1...4:
        command = 0b10000000 | (value ? 1 << (function - 1) : 0)
    case 5...8:
        command = 0b10110000 | (value ? 1 << (function - 5) : 0)
    case 9...12:
        command = 0b10100000 | (value ? 1 << (function - 9) : 0)
    default:
        return idlePacket
    }
    
    return Packet(bytes: [loco, command, loco ^ command])
}

let raspberryPi = try! RaspberryPi()

let driver = try! Driver(raspberryPi: raspberryPi)
driver.setup()

var packet: Packet? = resetPacket

loop: repeat {
    if let packet = packet {
        var bitstream = Bitstream()
        bitstream.append(operationsModePacket: packet, debug: true)
        
        let index = try! driver.queue(bitstream: bitstream)
        driver.start(at: index)
    }
    packet = nil

    print("> ", terminator: "")
    guard let line = readLine(strippingNewline: true) else { print(); break }
    
    switch line {
    case "exit", "quit":
        break loop
    case "start":
        packet = startPacket
    case "stop":
        packet = stopPacket
    case "idle":
        packet = idlePacket
    case "reset":
        packet = resetPacket
    case _ where line.hasPrefix("fon "):
        let function = Int(line.substring(from: line.index(line.startIndex, offsetBy: 4)))
        packet = functionPacket(function!, value: true)
    case _ where line.hasPrefix("foff "):
        let function = Int(line.substring(from: line.index(line.startIndex, offsetBy: 5)))
        packet = functionPacket(function!, value: false)
    default:
        print("?")
    }
    
} while true

driver.stop()
