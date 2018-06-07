//
//  BinaryString.swift
//  Util
//
//  Created by Scott James Remnant on 6/7/18.
//

public extension FixedWidthInteger {

    /// Returns the integer in the form of a full-width binary string.
    public var binaryString: String {
        var result: [String] = []
        for i in 0..<(Self.bitWidth / UInt8.bitWidth) {
            let byte = UInt8(truncatingIfNeeded: self >> (i * UInt8.bitWidth))
            let byteString = String(byte, radix: 2).leftPadding(toLength: UInt8.bitWidth, withPad: "0")
            result.append(byteString)
        }
        return result.reversed().joined()
    }

}
