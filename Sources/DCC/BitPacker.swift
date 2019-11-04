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
    public var results: [ResultType]
    
    /// Number of bits remaining in the final result.
    public var bitsRemaining = 0

    public init() {
        results = []
    }
    
    /// Add a field with the contents of a value.
    ///
    /// The length of the field is given in `length`. Only the least significant `length` bits from
    /// `value` are used for the contents of the field.
    ///
    /// A new result value is added whenever necessary to contain the length of all fields. Fields may
    /// span result value boundaries, and may be multiple result values in length.
    ///
    /// - parameters:
    ///   - value: value to add.
    ///   - length: length of the field.
    public mutating func add<T>(_ value: T, length: Int) where T : FixedWidthInteger {
        precondition(length > 0, "length must be greater than 0")
        precondition(length <= T.bitWidth, "length must be less than or equal to \(T.bitWidth)")
        
        var length = length
        repeat {
            if bitsRemaining < 1 {
                results.append(0)
                bitsRemaining = ResultType.bitWidth
            }
            
            let chunkLength = min(length, bitsRemaining)
            bitsRemaining -= chunkLength
            length -= chunkLength
            
            let bits = ResultType(truncatingIfNeeded: (value >> length) & T.mask(bits: chunkLength))
            results[results.index(before: results.endIndex)] |= bits << bitsRemaining
        } while length > 0
    }
}

// MARK: Debugging

extension BitPacker : CustomDebugStringConvertible {
    public var debugDescription: String {
        let bitsString = results.map({ $0.binaryString }).joined(separator: " ")
        return "<\(type(of: self)) \(bitsString), remaining: \(bitsRemaining)>"
    }
}
