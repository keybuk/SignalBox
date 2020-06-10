//
//  Address.swift
//  DCC
//
//  Created by Scott James Remnant on 6/9/20.
//

import Foundation

/// Decoder address.
///
/// DCC defines a number of different partitions of addresses.
///
/// - Note: NMRA S-9.2.1 A.
public enum Address : Hashable, Packable, CustomStringConvertible {
    /// Broadcast to all decoders.
    case broadcast

    /// Multi-function decoder with 7-bit address.
    case primary(Int)

    /// Multi-function decoder with 14-bit address.
    case extended(Int)

    /// Accessory decoder with 9-bit address.
    case accessory(Int)

    /// Accessory decoder with 14-bit address.
    case signal(Int)

    public func add<T>(into packer: inout T) where T : Packer {
        switch self {
        case .broadcast:
            packer.add(0, length: 8)
        case .primary(let address):
            precondition((1...127).contains(address),
                         "Primary address out of range 1...127")
            packer.add(0b0, length: 1)
            packer.add(address, length: 7)
        case .extended(let address):
            precondition((1...10239).contains(address),
                         "Extended address out of range 1...10239")
            packer.add(0b11, length: 2)
            packer.add(address, length: 14)
        case .accessory(let address):
            precondition((1...511).contains(address),
                         "Accessory address out of range 1...511")
            packer.add(0b10, length: 2)
            packer.add(address >> 3, length: 6)
            packer.add(0b1, length: 1)
            packer.add(~address, length: 3)
        case .signal(let address):
            precondition((1...2047).contains(address),
                         "Signal address out of range 1...2047")
            packer.add(0b10, length: 2)
            packer.add(address >> 5, length: 6)
            packer.add(0b0, length: 1)
            packer.add(address >> 2, length: 3)
            packer.add(0b0, length: 1)
            packer.add(address, length: 2)
            packer.add(0b1, length: 1)
        }
    }

    public var description: String {
        switch self {
        case .broadcast:
            return "broadcast"
        case .primary(let address):
            return "\(address)"
        case .extended(let address):
            return "\(address)".leftPadding(toLength: 4, with: "0")
        case .accessory(let address):
            return "Accessory(\(address))"
        case .signal(let address):
            return "Signal(\(address))"
        }
    }
}
