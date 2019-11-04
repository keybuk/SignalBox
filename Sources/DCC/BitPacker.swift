//
//  BitPacker.swift
//  DCC
//
//  Created by Scott James Remnant on 5/17/18.
//

import Util

/// Packs fields as bit fields into an array of fixed width integers.
///
/// `BitPacker` may be used to create arrays of integers by sourcing values of individual bits from other values, packing them into
/// the larger structure.
public struct BitPacker<ResultType : FixedWidthInteger> : Packer {
    // FIXME: rename this field.
    /// Packed results.
    public var bytes: [ResultType] = []
    
    /// Number of bits remaining in the final byte.
    public var bitsRemaining = 0
    
    /// Add a field with the contents of a value.
    ///
    /// The length of the field is given in `length`. Only the least significant `length` bits from
    /// `value` are used for the contents of the field.
    ///
    /// A new byte is added whenever necessary to contain the length of all fields. Fields may
    /// span byte boundaries, and may be multiple bytes in length.
    ///
    /// - parameters:
    ///   - value: value to add.
    ///   - length: length of the field.
    public mutating func add<T>(_ value: T, length: Int) where T : FixedWidthInteger {
        assert(length > 0, "length must be greater than 0")
        assert(length <= T.bitWidth, "length must be less than \(T.bitWidth)")
        
        var length = length
        repeat {
            if bitsRemaining < 1 {
                bytes.append(0)
                bitsRemaining = ResultType.bitWidth
            }
            
            let chunkLength = min(length, bitsRemaining)
            bitsRemaining -= chunkLength
            length -= chunkLength
            
            let bits = ResultType(truncatingIfNeeded: (value >> length) & T.mask(bits: chunkLength))
            bytes[bytes.index(before: bytes.endIndex)] |= bits << bitsRemaining
        } while length > 0
    }
}

// MARK: Debugging

extension BitPacker : CustomDebugStringConvertible {
    public var debugDescription: String {
        let bitsString = bytes.map({ $0.binaryString }).joined(separator: " ")
        return "<\(type(of: self)) \(bitsString), remaining: \(bitsRemaining)>"
    }
}
