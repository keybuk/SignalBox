//
//  PacketPacker.swift
//  DCC
//
//  Created by Scott James Remnant on 11/6/19.
//

import Foundation

/// Pass-through `Packer` for DCC packets.
///
/// `PacketPacker` passes values added to it through another `Packer` while inserting byte separation
/// bits and accumulatiing the error detection byte.
///
/// Values added should conform to the more strict structure of DCC address and instruction bytes, resulting
/// in exact multiples of eight bits.
///
/// `packedValues` is returned from the sub-packer, and includes the accumulated error detection byte. This
/// can only be accessed when the values added confirm to DCC requirements.
///
///      let signalPacker = SignalPacker(timing: SignalTiming(pulseWidth: 14.5))
///      var packer = PacketPacker(packer: signalPacker)
///      packer.add(0b10101100, 8)
///      let values = packer.packedValues
public struct PacketPacker<SubPacker>: Packer
where SubPacker: Packer {
    /// Internal wrapped `SubPacker` copy.
    private var packer: SubPacker
    
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

    /// Returns the structure of packed values from the wrapped `Packer`.

    /// Adds the error detection byte and packet end-bit, and may only be called when whole bytes have been packed.
    public var packedValues: SubPacker.PackedValues {
        precondition(bitsRemaining == 0, "Packet must consist of whole bytes")

        var packer = packer
        packer.add(0b0, length: 1)
        packer.add(errorDetectionByte)
        packer.add(0b1, length: 1)

        return packer.packedValues
    }
}

// MARK: Debugging

extension PacketPacker : CustomStringConvertible {
    public var description: String {
        "<\(type(of: self)) \(packer), error: \(errorDetectionByte.binaryString) remaining: \(bitsRemaining)>"
    }
}
