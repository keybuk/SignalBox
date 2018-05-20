//
//  UtilTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/15/18.
//

import XCTest

import DCC

class UtilTests: XCTestCase {

    /// Make sure that String.leftPadding works as intended.
    func testLeftPadding() {
        let padded = "foo".leftPadding(toLength: 5, withPad: " ")
        XCTAssertEqual(padded, "  foo")
    }
    
    /// Make sure that String.leftPadding works when the length is already equal.
    func testLeftPaddingEqual() {
        let padded = "foo".leftPadding(toLength: 3, withPad: " ")
        XCTAssertEqual(padded, "foo")
    }
    
    /// Make sure that String.leftPadding works when the length is already greater.
    func testLeftPaddingGreater() {
        let padded = "foobar".leftPadding(toLength: 3, withPad: " ")
        XCTAssertEqual(padded, "foobar")
    }

    
    /// Make sure that we can get the binary representation of an integer.
    func testBinaryString() {
        let value: UInt8 = 42
        XCTAssertEqual(value.binaryString, "00101010")
    }
    
}
