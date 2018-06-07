//
//  MaskTests.swift
//  UtilTests
//
//  Created by Scott James Remnant on 6/7/18.
//

import XCTest

import Util

class MaskTests : XCTestCase {

    /// Thest that we can create a mask without a number of bits.
    func testMaskExcept() {
        let value = UInt8.mask(except: 3)
        XCTAssertEqual(value, 0b11111000)
    }

    /// Test that we can create a mask of a number of bits.
    func testMaskBits() {
        let value = UInt8.mask(bits: 3)
        XCTAssertEqual(value, 0b00000111)
    }

    /// Test that we can create an offset mask of a number of bits.
    func testMaskBitsOffset() {
        let value = UInt8.mask(bits: 3, offset: 2)
        XCTAssertEqual(value, 0b00011100)
    }

    /// Test that we can create an offset mask without a number of bits.
    func testMaskExceptOffset() {
        let value = UInt8.mask(except: 3, offset: 2)
        XCTAssertEqual(value, 0b11100011)
    }

}
