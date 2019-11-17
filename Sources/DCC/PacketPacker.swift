//
//  PacketPacker.swift
//  DCC
//
//  Created by Scott James Remnant on 11/6/19.
//

import Foundation

/// Pass-through `Packer` for DCC packets.
///
/// `PacketPacker` passes values added to it through another `Packer` while inserting byte separation bits and accumulatiing
/// the error detection byte.
///
/// Values added should conform to the more strict structure of DCC address and instruction bytes, resulting in exact multiples of
/// eight bits.
///
/// Additionally to add the accumulated error detection byte and return the internal copy of the wrapped `Packer`, `finish`
/// must be called.
///
/// # Example:
///      var signalPacker = SignalPacker(timing: SignalTiming(pulseWidth: 14.5))
///      var packer = PacketPacker(packer: signalPacker)
///      packer.add(0b10101100, 8)
///      signalPacker = packer.finish()
public struct PacketPacker<SubPacker> : Packer
where SubPacker : Packer {
    /// Wrapped `Packer` copy.
    public var packer: SubPacker

    /// Number of bits remaining in the current byte.
    private var bitsRemaining = 0

    /// Accumulated error detection byte.
    private var errorDetectionByte: UInt8 = 0

    public init(packer: SubPacker) {
        self.packer = packer
    }

    public mutating func add<T>(_ value: T, length: Int) where T : FixedWidthInteger {
        precondition(length > 0, "length must be greater than 0")
        precondition(length <= T.bitWidth, "length must be less than or equal to \(T.bitWidth)")

        var length = length
        repeat {
            if bitsRemaining == 0 {
                bitsRemaining = 8
                packer.add(0b0, length: 1)
            }

            let chunkLength = min(bitsRemaining, length)
            bitsRemaining -= chunkLength
            length -= chunkLength

            packer.add(value >> length, length: chunkLength)

            let bits = UInt8(truncatingIfNeeded: value >> length) & UInt8.mask(bits: chunkLength)
            errorDetectionByte ^= bits << bitsRemaining
        } while length > 0
    }

    /// Returns the internal copy of the wrapped `Packer`.
    ///
    /// Adds the error detection byte and packet end-bit, and then returns the internal copy of `packer` which has had the
    /// called `add(:length:)` methods called on it.
    public mutating func finish() -> SubPacker {
        precondition(bitsRemaining == 0, "Packet must consist of whole bytes")

        packer.add(0b0, length: 1)
        packer.add(errorDetectionByte)
        packer.add(0b1, length: 1)

        return packer
    }
}

// MARK: Debugging

extension PacketPacker : CustomStringConvertible {
    public var description: String {
        "<\(type(of: self)) \(packer), error: \(errorDetectionByte.binaryString) remaining: \(bitsRemaining)>"
    }
}
