//
//  HexString.swift
//  Util
//
//  Created by Scott James Remnant on 6/12/18.
//

extension FixedWidthInteger {
    /// Returns the integer in the form of a hexadecimal string prefixed with '0x'.
    public var hexString: String {
        "0x" + String(self, radix: 16)
    }
}

extension FixedWidthInteger where Self : SignedNumeric {
    /// Returns the integer in the form of a hexadecimal string prefixed with '0x'.
    public var hexString: String {
        let value = abs(self)
        return (value == self ? "" : "-") + "0x" + String(value, radix: 16)
    }
}
