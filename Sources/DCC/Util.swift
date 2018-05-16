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
        return String(self, radix: 2).leftPadding(toLength: bitWidth, withPad: "0")
    }
    
}
