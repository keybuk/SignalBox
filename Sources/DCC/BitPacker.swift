//
//  BitPacker.swift
//  DCC
//
//  Created by Scott James Remnant on 5/17/18.
//

import Util

public typealias BytePacker = BitPacker<UInt8>

/// Packs fields as bit fields into an array of bytes.
///
/// `BitPacker` may be used to create arrays of bytes by sourcing values of individual bits from
/// other values, packing them into the larger structure.
///
/// In addition to the serial `Packer` conformance, values can be added at fields with specific
/// positions within a byte.
public struct BitPacker<ResultType : FixedWidthInteger> : Packer, CustomDebugStringConvertible {
    
    /// Packed bytes.
    public var bytes: [ResultType]
    
    /// Number of bits remaining in the final byte.
    public var bitsRemaining = 0
    
    public init() {
        bytes = []
    }
    
    public var debugDescription: String {
        let bitsString = bytes.map({ $0.binaryString }).joined(separator: " ")
        return "<\(type(of: self)) \(bitsString), remaining: \(bitsRemaining)>"
    }
    
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
    
    /// Add a field with the contents of a value.
    ///
    /// Fields are described by a position and a length; the position is given in `at` and gives
    /// the bit number of the most signifiant bit of the field, with a range of 0 to 7 inclusive.
    ///
    /// The length of the bit field is given in `length`. Only the least significant `length` bits
    /// from `value` are used for the contents of the field.
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
            
            let bits = ResultType(truncatingIfNeeded: (value >> length) & T.mask(bits: chunkLength))
            bytes[bytes.index(before: bytes.endIndex)] |= bits << bitsRemaining
        } while length > 0
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
