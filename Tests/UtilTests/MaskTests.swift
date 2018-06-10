//
//  MaskTests.swift
//  UtilTests
//
//  Created by Scott James Remnant on 6/7/18.
//

import XCTest

import Util

class MaskTests : XCTestCase {

    // MARK: mask(except:)
    
    /// Test that we can create a mask without a number of bits.
    func testMaskExcept() {
        let value = UInt8.mask(except: 3)
        XCTAssertEqual(value, 0b11111000)
    }

    /// Test that we can create a mask of all bits.
    func testMaskExceptZero() {
        let value = UInt8.mask(except: 0)
        XCTAssertEqual(value, 0b11111111)
    }

    /// Test that we can create a mask of no bits.
    func testMaskExceptAll() {
        let value = UInt8.mask(except: 8)
        XCTAssertEqual(value, 0b00000000)
    }

    
    // MARK: mask(bits:)
    
    /// Test that we can create a mask of a number of bits.
    func testMaskBits() {
        let value = UInt8.mask(bits: 3)
        XCTAssertEqual(value, 0b00000111)
    }

    /// Test that we can create a mask of no bits.
    func testMaskBitsZero() {
        let value = UInt8.mask(bits: 0)
        XCTAssertEqual(value, 0b00000000)
    }

    /// Test that we can create a mask of all bits.
    func testMaskBitsAll() {
        let value = UInt8.mask(bits: 8)
        XCTAssertEqual(value, 0b11111111)
    }
    
    
    // MARK: mask(bits:offset:)

    /// Test that we can create an offset mask of a number of bits.
    func testMaskBitsOffset() {
        let value = UInt8.mask(bits: 3, offset: 2)
        XCTAssertEqual(value, 0b00011100)
    }

    /// Test that we can create an offset mask of a number of bits, with no offset.
    func testMaskBitsOffsetZero() {
        let value = UInt8.mask(bits: 3, offset: 0)
        XCTAssertEqual(value, 0b00000111)
    }

    /// Test that we can create an offset mask of no bits.
    func testMaskBitsZeroOffset() {
        let value = UInt8.mask(bits: 0, offset: 2)
        XCTAssertEqual(value, 0b00000000)
    }

    
    // MARK: mask(except: offset:)
    
    /// Test that we can create an offset mask without a number of bits.
    func testMaskExceptOffset() {
        let value = UInt8.mask(except: 3, offset: 2)
        XCTAssertEqual(value, 0b11100011)
    }
    /// Test that we can create an no offset mask without a number of bits.
    func testMaskExceptOffsetZero() {
        let value = UInt8.mask(except: 3, offset: 0)
        XCTAssertEqual(value, 0b11111000)
    }

    /// Test that we can create an offset mask without bits.
    func testMaskExceptZeroOffset() {
        let value = UInt8.mask(except: 0, offset: 2)
        XCTAssertEqual(value, 0b11111111)
    }

}
