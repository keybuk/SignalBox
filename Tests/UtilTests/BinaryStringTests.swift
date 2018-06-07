//
//  BinaryStringTests.swift
//  UtilTests
//
//  Created by Scott James Remnant on 6/7/18.
//

import XCTest

import Util

class BinaryStringTests : XCTestCase {

    /// Make sure that we can get the binary representation of an integer.
    func testBinaryString() {
        let value: UInt8 = 42
        XCTAssertEqual(value.binaryString, "00101010")
    }

    /// Make sure that we can get the binary representation of a negative integer.
    func testNegativeBinaryString() {
        let value: Int8 = -42
        XCTAssertEqual(value.binaryString, "11010110")
    }

}
