//
//  BitPackerTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/15/18.
//

import XCTest

import DCC

class BitPackerTests : XCTestCase {
    
    /// Add a value to an unsigned type.
    func testUnsigndType() {
        var packer = BitPacker<UInt8>()
        packer.add(0b1111, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b11110000 ])
    }

    /// Add a value to a signed type.
    func testSignedType() {
        var packer = BitPacker<Int8>()
        packer.add(0b1111, length: 4)
        
        XCTAssertEqual(packer.bytes, [ Int8(bitPattern: 0b11110000) ])
    }

    /// Add multiple values.
    func testMultipleValues() {
        var packer = BitPacker<UInt8>()
        packer.add(0b1010, length: 4)
        packer.add(0b1111, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10101111 ])
    }

    /// Adding a value can extend into a new byte.
    func testExtendingValue() {
        var packer = BitPacker<UInt8>()
        packer.add(0b10, length: 2)
        packer.add(0b11111111, length: 8)
        
        XCTAssertEqual(packer.bytes, [ 0b10111111, 0b11000000 ])
    }
    
    /// Add a value that is longer than a byte.
    func testLongValue() {
        var packer = BitPacker<UInt8>()
        packer.add(0b11000011_11000011, length: 16)
        
        XCTAssertEqual(packer.bytes, [ 0b011000011, 0b11000011 ])
    }

    /// Add a single bit field with true.
    func testAddTrue() {
        var packer = BitPacker<UInt8>()
        packer.add(true)
        
        XCTAssertEqual(packer.bytes, [ 0b10000000 ])
    }
    
    /// Add a single bit field with false.
    func testAddFalse() {
        var packer = BitPacker<UInt8>()
        packer.add(false)
        
        XCTAssertEqual(packer.bytes, [ 0b00000000 ])
    }

    /// Add multiple single bit fields.
    func testMultipleSingleBits() {
        var packer = BitPacker<UInt8>()
        packer.add(false)
        packer.add(true)
        
        XCTAssertEqual(packer.bytes, [ 0b01000000 ])
    }

    /// Signed values should still have all bits accessible.
    func testSignedValue() {
        let value: Int8 = -1
        var packer = BitPacker<UInt8>()
        packer.add(value, length: 8)
        
        XCTAssertEqual(packer.bytes, [ 0b11111111 ])
    }

    /// Test that we can add an homogenous array of packable things.
    func testArrayOfPackables() {
        let values: [UInt8] = [ 0b11110000, 0b11001100, 0b10101010, 0b11100010 ]
        var packer = BitPacker<UInt32>()
        packer.add(values)

        XCTAssertEqual(packer.bytes, [ 0b11110000_11001100_10101010_11100010 ])
    }

}
