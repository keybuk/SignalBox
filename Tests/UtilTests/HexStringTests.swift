//
//  HexStringTests.swift
//  UtilTests
//
//  Created by Scott James Remnant on 6/12/18.
//

import XCTest

import Util

class HexStringTests : XCTestCase {
        
    /// Make sure that we can get the hex representation of an integer.
    func testHexString() {
        let value: UInt32 = 0xdeadbeef
        XCTAssertEqual(value.hexString, "0xdeadbeef")
    }

    /// Make sure that we can get the hex representation of a negative integer.
    func testNegativeHexString() {
        let value: Int32 = -0xc0ffee
        XCTAssertEqual(value.hexString, "-0xc0ffee")
    }

    /// Make sure that we can get the hex representation of a positive signed integer.
    func testPositiveHexString() {
        let value: Int32 = 0xc0ffee
        XCTAssertEqual(value.hexString, "0xc0ffee")
    }

}
