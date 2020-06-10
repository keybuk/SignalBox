//
//  Address.swift
//  DCC
//
//  Created by Scott James Remnant on 11/6/19.
//

import Foundation

public enum MultiFunctionAddress : Packable, CustomStringConvertible {
    case broadcast
    case primary(Int)
    case extended(Int)
    // basicAccessory(address, pair, output) - not separate from the active/inactive
    // extendedAccessory(address, aspect) - aspect is really the command!

    public func add<T>(into packer: inout T) where T : Packer {
        switch self {
        case .broadcast:
            packer.add(0, length: 8)
        case .primary(let address):
            packer.add(0b0, length: 1)
            packer.add(address, length: 7)
        case .extended(let address):
            packer.add(0b11, length: 2)
            packer.add(address, length: 14)
        }
    }

    public var description: String {
        switch self {
        case .broadcast: return "broadcast"
        case .primary(let address): return "\(address)".leftPadding(toLength: 2, with: "0")
        case .extended(let address): return "\(address)".leftPadding(toLength: 4, with: "0")
        }
    }
}
