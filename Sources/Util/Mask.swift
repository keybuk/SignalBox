//
//  Mask.swift
//  Util
//
//  Created by Scott James Remnant on 6/7/18.
//

public extension FixedWidthInteger {

    /// Create a bit mask
    ///
    /// - Parameters:
    ///   - bits: the number of right-most bits to be not set.
    ///
    /// - Returns: a mask with all bits except the right-most `bits` set.
    @inline(__always)
    public static func mask(except bits: Int) -> Self {
        return ~0 << bits
    }

    /// Create a bit mask
    ///
    /// - Parameters:
    ///   - bits: the number of right-most bits to be set.
    ///
    /// - Returns: a mask with only the right-most `bits` set.
    @inline(__always)
    public static func mask(bits: Int) -> Self {
        return ~Self.mask(except: bits)
    }

    /// Create a bit mask
    ///
    /// - Parameters:
    ///   - bits: the number of bits to be set.
    ///   - offset: the offset from the right-most bit of `bits`.
    ///
    /// - Returns: a mask with only `bits` set, offset `offset` bits from the right-most bit.
    @inline(__always)
    public static func mask(bits: Int, offset: Int) -> Self {
        return Self.mask(bits: bits) << offset
    }

    /// Create a bit mask
    ///
    /// - Parameters:
    ///   - bits: the number of bits to be not set.
    ///   - offset: the offset from the right-most bit of `bits`.
    ///
    /// - Returns:  a mask with all bits set except `bits` offset `offset` bits from the right-most bit.
    @inline(__always)
    public static func mask(except bits: Int, offset: Int) -> Self {
        return ~Self.mask(bits: bits, offset: offset)
    }

}
