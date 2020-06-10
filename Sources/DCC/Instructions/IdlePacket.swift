//
//  IdlePacket.swift
//  DCC
//
//  Created by Scott James Remnant on 11/7/19.
//

import Foundation

public struct IdlePacket : Packable, CustomStringConvertible {
    public func add<T>(into packer: inout T) where T : Packer {
        var packetPacker = PacketPacker(packer: packer)
        packetPacker.add(0b11111111, length: 8)
        packetPacker.add(0b00000000, length: 8)
        packer = packetPacker.finish()
    }

    public var description: String {
        "<IdlePacket>"
    }
}
