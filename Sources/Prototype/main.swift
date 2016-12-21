//
//  main.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

let packet = Packet(bytes: [0b00000011, 0b01111000, 0b01111011])

let bitstream = Bitstream(wordSize: 32)
bitstream.addOperationsModePacket(packet, debug: true)

let driver = Driver()
driver.go(bitstream: bitstream)
