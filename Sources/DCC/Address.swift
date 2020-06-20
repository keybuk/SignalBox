//
//  Address.swift
//  DCC
//
//  Created by Scott James Remnant on 6/9/20.
//

import Foundation

/// Decoder address.
///
/// To send instructions to a digital decoder, the instruction must be identified with the decoder's address. DCC defines a number of
/// different partitions of addresses for both multi-function (locomotive) and accessory decoders. Each partition is a discrete
/// namespace, the same numerical addresses in two different partitions address different decoders.
///
/// Addresses are comparable within a partition, with each partition comparing separately to others by bit pattern value.
///
/// `Address` conforms to `Packable` and produces complete 8-bit bytes, except for `.accessory(_)` which leaves
/// 4-bits remaining in the second byte for identifying the command and pair.
///
/// - Note:
/// Primary address is defined by the baseline packet format in NMRA S-9.2 B, other address partitions are defined in
/// NMRA S-9.2.1 A.
public enum Address : Hashable {
    /// Broadcast to multi-function decoders.
    case broadcast

    /// Multi-function decoder with 7-bit address.
    ///
    /// Address has range 1...127, values outside this range are truncated by bit pattern.
    case primary(Int)

    /// Multi-function decoder with 14-bit address.
    ///
    /// Address has range 0...10239, values outside this range are truncated by bit pattern.
    case extended(Int)

    /// Basic accessory decoder with 9-bit address.
    ///
    /// Address has range 1...510, values outside this range are truncated by bit pattern.
    case accessory(Int)

    /// Broadcast to basic accessory decoders.
    case accessoryBroadcast

    /// Extended accessory decoder with 14-bit address.
    ///
    /// This address partition is primarily used for signal aspect control.
    ///
    /// Address has range 1...2046, values outside this range are truncated by bit pattern.
    case signal(Int)

    /// Broadcast to extended accessory decoders.
    case signalBroadcast
}

extension Address : Packable {
    public func add<T>(into packer: inout T) where T : Packer {
        switch self {
        case .broadcast:
            packer.add(0, length: 8)
        case .primary(let address):
            assert((1...127).contains(address),
                   "Primary address out of range 1...127")
            packer.add(0b0, length: 1)
            packer.add(address, length: 7)
        case .extended(let address):
            assert((0...10239).contains(address),
                   "Extended address out of range 0...10239")
            packer.add(0b11, length: 2)
            packer.add(address, length: 14)
        case .accessory(let address):
            assert((1...510).contains(address),
                   "Accessory address out of range 1...510")
            packer.add(0b10, length: 2)
            packer.add(address >> 3, length: 6)
            packer.add(0b1, length: 1)
            packer.add(~address, length: 3)
        case .accessoryBroadcast:
            // Effectively address 511 (0x1ff).
            packer.add(0b10, length: 2)
            packer.add(0b111111, length: 6)
            packer.add(0b1, length: 1)
            packer.add(~0b111, length: 3)  // 0b000
        case .signal(let address):
            assert((1...2046).contains(address),
                   "Signal address out of range 1...2046")
            packer.add(0b10, length: 2)
            packer.add(address >> 5, length: 6)
            packer.add(0b0, length: 1)
            // Standard doesn't clarify whether these bits are ones complement or not,
            // but the bits being 0 for the broadcast address strongly implies it.
            packer.add(~address >> 2, length: 3)
            packer.add(0b0, length: 1)
            packer.add(address, length: 2)
            packer.add(0b1, length: 1)
        case .signalBroadcast:
            // Effectively address 2047 (0x7ff).
            packer.add(0b10, length: 2)
            packer.add(0b111111, length: 6)
            packer.add(0b0, length: 1)
            // Implied to be 0b111 in ones complement.
            packer.add(~0b111, length: 3)  // 0b000
            packer.add(0b0, length: 1)
            packer.add(0b11, length: 2)
            packer.add(0b1, length: 1)
        }
    }
}

extension Address : Comparable {
    public static func < (lhs: Address, rhs: Address) -> Bool {
        switch (lhs, rhs) {
        case (.broadcast, .broadcast): return false
        case (.broadcast, _): return true
        case (.primary(let lhsAddress), .primary(let rhsAddress)):
            return lhsAddress < rhsAddress
        case (.primary(_), _): return true
        // Accessories sorts between primary and extended.
        case (.accessory(let lhsAddress), .accessory(let rhsAddress)):
            return lhsAddress < rhsAddress
        case (.accessory(_), _): return true
        case (.accessoryBroadcast, .accessoryBroadcast): return false
        case (.accessoryBroadcast, _): return true
        case (.signal(let lhsAddress), .signal(let rhsAddress)):
            return lhsAddress < rhsAddress
        case (.signal(_), _): return true
        case (.signalBroadcast, .signalBroadcast): return false
        case (.signalBroadcast, _): return true
        case (.extended(let lhsAddress), .extended(let rhsAddress)):
            return lhsAddress < rhsAddress
        case (.extended(_), _): return true
        }
    }
}

extension Address : CustomStringConvertible {
    public var description: String {
        switch self {
        case .broadcast: return "broadcast"
        case .primary(let address): return "\(address)"
        case .extended(let address):
            return "\(address)".leftPadding(toLength: 4, with: "0")
        case .accessory(let address): return "Accessory(\(address))"
        case .accessoryBroadcast: return "Accessory(broadcast)"
        case .signal(let address): return "Signal(\(address))"
        case .signalBroadcast: return "Signal(broadcast)"
        }
    }
}
