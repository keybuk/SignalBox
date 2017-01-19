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

let locoAddress: Address = 3

let resetPacket: Packet = .softReset(address: .broadcast)
let idlePacket: Packet = .idle
let startPacket: Packet = .speed28Step(address: locoAddress, direction: .forward, speed: 14)
let stopPacket: Packet = .stop28Step(address: locoAddress, direction: .ignore)

func functionPacket(_ function: Int, value: Bool) -> Packet {
    switch function {
    case 0:
        return .function0To4(address: locoAddress, headlight: true, f1: false, f2: false, f3: false, f4: false)

    case 1:
        return .function0To4(address: locoAddress, headlight: false, f1: true, f2: false, f3: false, f4: false)
    case 2:
        return .function0To4(address: locoAddress, headlight: false, f1: false, f2: true, f3: false, f4: false)
    case 3:
        return .function0To4(address: locoAddress, headlight: false, f1: false, f2: false, f3: true, f4: false)
    case 4:
        return .function0To4(address: locoAddress, headlight: false, f1: false, f2: false, f3: false, f4: true)

    case 5:
        return .function5To8(address: locoAddress, f5: true, f6: false, f7: false, f8: false)
    case 6:
        return .function5To8(address: locoAddress, f5: false, f6: true, f7: false, f8: false)
    case 7:
        return .function5To8(address: locoAddress, f5: false, f6: false, f7: true, f8: false)
    case 8:
        return .function5To8(address: locoAddress, f5: false, f6: false, f7: false, f8: true)

    case 9:
        return .function9To12(address: locoAddress, f9: true, f10: false, f11: false, f12: false)
    case 10:
        return .function9To12(address: locoAddress, f9: false, f10: true, f11: false, f12: false)
    case 11:
        return .function9To12(address: locoAddress, f9: false, f10: false, f11: true, f12: false)
    case 12:
        return .function9To12(address: locoAddress, f9: false, f10: false, f11: false, f12: true)
        
    default:
        return .idle
    }
}

let raspberryPi = try RaspberryPi()

var driver = try! Driver(raspberryPi: raspberryPi)
driver.startup()

var startupBitstream = Bitstream(bitDuration: driver.bitDuration)
startupBitstream.append(.railComCutoutEnd)
for _ in 0..<20 {
    startupBitstream.appendPreamble()
    startupBitstream.append(packet: .softReset(address: .broadcast))
}
startupBitstream.append(.loopStart)
for _ in 0..<10 {
    startupBitstream.appendPreamble()
    startupBitstream.append(packet: .idle)
}

print("One bit has length \(startupBitstream.oneBitLength)b, and duration \(Float(startupBitstream.oneBitLength) * startupBitstream.bitDuration)µs")
print("Zero bit has length \(startupBitstream.zeroBitLength)b, and duration \(Float(startupBitstream.zeroBitLength) * startupBitstream.bitDuration)µs")
print("RailCom delay has length \(startupBitstream.railComDelayLength)b, and duration \(Float(startupBitstream.railComDelayLength) * startupBitstream.bitDuration)µs")
print("RailCom cutout has length \(startupBitstream.railComCutoutLength)b, and duration \(Float(startupBitstream.railComCutoutLength) * startupBitstream.bitDuration)µs")
print()

try! driver.queue(bitstream: startupBitstream)

loop: while true {
    print("> ", terminator: "")
    guard let line = readLine(strippingNewline: true) else { print(); break }

    var packet: Packet?
    var debug  = true
    switch line {
    case "exit", "quit":
        break loop
    case "start":
        packet = startPacket
    case "stop":
        packet = stopPacket
    case "idle":
        packet = idlePacket
        debug = false
    case "reset":
        packet = resetPacket
        debug = false
    case _ where line.hasPrefix("fon "):
        let function = Int(line.substring(from: line.index(line.startIndex, offsetBy: 4)))
        packet = functionPacket(function!, value: true)
    case _ where line.hasPrefix("foff "):
        let function = Int(line.substring(from: line.index(line.startIndex, offsetBy: 5)))
        packet = functionPacket(function!, value: false)
    default:
        print("?")
    }
    
    if let packet = packet {
        var bitstream = Bitstream(bitDuration: driver.bitDuration)
        bitstream.append(operationsModePacket: packet, debug: debug)
        
        try! driver.queue(bitstream: bitstream)
    }
    packet = nil
}

driver.shutdown()
