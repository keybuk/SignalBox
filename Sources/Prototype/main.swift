//
//  main.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

let packet = Packet(bytes: [0b00000011, 0b01111000, 0b01111011])

var bitstream = Bitstream(wordSize: 32)
bitstream.append(operationsModePacket: packet, debug: true)

let driver = Driver()
do {
    try driver.go(bitstream: bitstream)
} catch {
    print("FAILED")
}
