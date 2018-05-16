//
//  BitPacker.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

import Foundation


/// A type that can pack its values into sequences of bits.
public protocol BitPackable {

    /// Adds the values from this type into the given packer.
    ///
    /// - parameters:
    ///   - packer: The packer to add to.
    func add(into packer: inout BitPacker)
    
}


/// Packs sequences of bits into an array of bytes.
///
/// `BitPacker` may be used to create arrays of bytes by sourcing values of individual bits from
/// integers and values, packing their bits into the larger structure.
///
/// Values can be added serially, or at fields with specific positions within a byte.
public struct BitPacker : CustomDebugStringConvertible {
    
    /// Packed bytes.
    public var bytes: [UInt8]
    
    /// Number of bits remaining in the final byte.
    public var bitsRemaining = 0
    
    public init() {
        bytes = []
    }
    
    public var debugDescription: String {
        let bitsString = bytes.map({ $0.binaryString }).joined(separator: " ")
        return "<BitPacker \(bitsString), remaining: \(bitsRemaining)>"
    }
    
    /// Add a bit field with the contents of a value.
    ///
    /// The length of the bit field is given in `length`. Only the lowest `length` bits from
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
                bitsRemaining = UInt8.bitWidth
            }
            
            let chunkLength = min(length, bitsRemaining)
            bitsRemaining -= chunkLength
            length -= chunkLength
            
            let mask: T = ~(~0 << chunkLength)
            let bits = UInt8(truncatingIfNeeded: (value >> length) & mask)
            bytes[bytes.index(before: bytes.endIndex)] |= bits << bitsRemaining
        } while length > 0
    }

    /// Add a bit field with the contents of a value.
    ///
    /// Fields are described by a position and a length; the position is given in `at` and gives
    /// the bit number of the most signifiant bit of the field, with a range of 0 to 7 inclusive.
    ///
    /// The length of the bit field is given in `length`. Only the lowest `length` bits from
    /// `value` are used for the contents of the field.
    ///
    /// A new byte is added when a new bit field is added which would overlap any previously
    /// added bit field, or when necessary to contain the length of all fields.
    ///
    /// Fields may span byte boundaries, and may be multiple bytes in length.
    ///
    /// - parameters:
    ///   - value: value to add.
    ///   - at: bit position where the field starts, range 0...7
    ///   - length: length of the field.
    public mutating func add<T>(_ value: T, at: Int, length: Int) where T : FixedWidthInteger {
        // FIXME: I'm not sure this will be necessary
        assert(at < 8, "at must be in range 0..<8")
        assert(length > 0, "length must be greater than 0")
        assert(length <= value.bitWidth, "length must be less than \(value.bitWidth)")
        
        var at = at, length = length
        repeat {
            if at >= bitsRemaining {
                bytes.append(0)
            }
            
            let chunkLength = min(length, at + 1)
            bitsRemaining = at - chunkLength + 1
            at = 7
            length -= chunkLength
            
            let mask: T = ~(~0 << chunkLength)
            let bits = UInt8(truncatingIfNeeded: (value >> length) & mask)
            bytes[bytes.index(before: bytes.endIndex)] |= bits << bitsRemaining
        } while length > 0
    }
    
    /// Add a single bit field with the given value.
    ///
    /// A new byte is added whenever necessary to contain the length of all fields.
    ///
    /// - parameters:
    ///   - value: whether to set the bit to 1 or 0.
    public mutating func add(_ value: Bool) {
        if bitsRemaining < 1 {
            bytes.append(0)
            bitsRemaining = UInt8.bitWidth
        }

        bitsRemaining -= 1
        
        if value {
            bytes[bytes.index(before: bytes.endIndex)] |= 1 << bitsRemaining
        }
    }
    
    /// Set the value of an individual bit in a bit field.
    ///
    /// A new byte is added whenever necessary to contain the length of all fields.
    ///
    /// - parameters:
    ///   - value: whether to set the bit to 1 or 0.
    ///   - at: bit position of the field, range 0...7.
    public mutating func add(_ value: Bool, at: Int) {
        // FIXME: I'm not sure this will be necessary
        assert(at < 8, "at must be in range 0..<8")

        if at >= bitsRemaining {
            bytes.append(0)
        }

        bitsRemaining = at

        if value {
            bytes[bytes.index(before: bytes.endIndex)] |= 1 << bitsRemaining
        }
    }
    
}
