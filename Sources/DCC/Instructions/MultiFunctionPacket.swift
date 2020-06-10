//
//  MultiFunctionPacket.swift
//  DCC
//
//  Created by Scott James Remnant on 11/6/19.
//

import Foundation

public struct MultiFunctionPacket<InstructionType> : Packable, CustomStringConvertible
where InstructionType : Packable {
    public var address: MultiFunctionAddress
    public var instruction: InstructionType

    public init(address: MultiFunctionAddress, instruction: InstructionType) {
        self.address = address
        self.instruction = instruction
    }

    public func add<T>(into packer: inout T) where T : Packer {
        var packetPacker = PacketPacker(packer: packer)
        packetPacker.add(address)
        packetPacker.add(instruction)
        packer = packetPacker.finish()
    }

    public var description: String {
        "<MultiFunctionPacket \(address) \(instruction)>"
    }
}


public struct MultiFunctionPacket2<InstructionType1, InstructionType2> : Packable, CustomStringConvertible
where InstructionType1 : Packable, InstructionType2 : Packable {
    public var address: MultiFunctionAddress
    public var instructions: (InstructionType1, InstructionType2)

    public init(address: MultiFunctionAddress, instructions instruction1: InstructionType1, _ instruction2: InstructionType2) {
        self.address = address
        self.instructions = (instruction1, instruction2)
    }

    public func add<T>(into packer: inout T) where T : Packer {
        var packetPacker = PacketPacker(packer: packer)
        packetPacker.add(address)
        packetPacker.add(instructions.0)
        packetPacker.add(instructions.1)
        packer = packetPacker.finish()
    }

    public var description: String {
        "<MultiFunctionPacket \(address) \(instructions.0) \(instructions.1)>"
    }
}
