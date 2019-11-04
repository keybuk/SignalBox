//
//  BinaryString.swift
//  Util
//
//  Created by Scott James Remnant on 6/7/18.
//

extension FixedWidthInteger {
    /// Returns the individual bytes of the integer.
    private var bytes: [UInt8] {
        stride(from: 0, to: Self.bitWidth, by: UInt8.bitWidth)
            .map { UInt8(truncatingIfNeeded: self >> $0) }
            .reversed()
    }

    /// Returns the integer in the form of a full-width binary string.
    public var binaryString: String {
        bytes
            .map { String($0, radix: 2).leftPadding(toLength: $0.bitWidth, withPad: "0") }
            .joined()
    }
}
