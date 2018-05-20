//
//  Util.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

import Foundation

public extension String {

    /// Returns a new string formed from by adding as many occurrences of `character` are necessary to the start to reach a length of `length`.
    public func leftPadding(toLength length: Int, withPad character: Character) -> String {
        return String(repeating: String(character), count: max(0, length - self.count)) + self
    }
    
}

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
