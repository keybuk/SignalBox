//
//  BytePackerTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/15/18.
//

import XCTest

import DCC


class BytePackerTests: XCTestCase {
    
    /// Add a value.
    func testAdd() {
        var packer = BytePacker()
        packer.add(0b1111, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b11110000 ])
    }
    
    /// Add a value at the top of a byte.
    func testStartOfByte() {
        var packer = BytePacker()
        packer.add(0b1111, at: 7, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b11110000 ])
    }
    
    /// Add a value in the middle of a byte.
    func testMiddleOfByte() {
        var packer = BytePacker()
        packer.add(0b1111, at: 5, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b00111100 ])
    }
    
    /// Add a value at the end of a byte.
    func testEndOfByte() {
        var packer = BytePacker()
        packer.add(0b1111, at: 3, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b00001111 ])
    }
    
    /// Add multiple values.
    func testMultipleValues() {
        var packer = BytePacker()
        packer.add(0b1010, length: 4)
        packer.add(0b1111, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10101111 ])
    }

    /// Add consecutive values within a byte.
    func testConsecutiveValues() {
        var packer = BytePacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.add(0b1111, at: 3, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10101111 ])
    }
    
    /// Add a new value at the top of a byte.
    func testValueStartsNewByte() {
        var packer = BytePacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.add(0b1111, at: 7, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10100000, 0b11110000 ])
    }
    
    /// Adding an overlapping value starts a new byte.
    func testOverlappingValue() {
        var packer = BytePacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.add(0b1111, at: 5, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10100000, 0b00111100 ])
    }
    
    /// Adding a value can extend into a new byte.
    func testExtendingValue() {
        var packer = BytePacker()
        packer.add(0b10, length: 2)
        packer.add(0b11111111, length: 8)
        
        XCTAssertEqual(packer.bytes, [ 0b10111111, 0b11000000 ])
    }
    
    /// Adding a value with an offset can extend into a new byte.
    func testExtendingConsecutiveValue() {
        var packer = BytePacker()
        packer.add(0b10, at: 7, length: 2)
        packer.add(0b11111111, at: 5, length: 8)
        
        XCTAssertEqual(packer.bytes, [ 0b10111111, 0b11000000 ])
    }

    /// Add a value that is longer than a byte.
    func testLongValue() {
        var packer = BytePacker()
        packer.add(0b11000011_11000011, length: 16)
        
        XCTAssertEqual(packer.bytes, [ 0b011000011, 0b11000011 ])
    }
    
    /// Add a value that is longer than a byte with an offset.
    func testLongValueAtOffset() {
        var packer = BytePacker()
        packer.add(0b11000011_11000011, at: 5, length: 16)
        
        XCTAssertEqual(packer.bytes, [ 0b000110000, 0b11110000, 0b11000000 ])
    }
    

    /// Add a single bit field with true.
    func testAddTrue() {
        var packer = BytePacker()
        packer.add(true)
        
        XCTAssertEqual(packer.bytes, [ 0b10000000 ])
    }
    
    /// Add a single bit field with false.
    func testAddFalse() {
        var packer = BytePacker()
        packer.add(false)
        
        XCTAssertEqual(packer.bytes, [ 0b00000000 ])
    }

    /// Add multiple single bit fields.
    func testMultipleSingleBits() {
        var packer = BytePacker()
        packer.add(false)
        packer.add(true)
        
        XCTAssertEqual(packer.bytes, [ 0b01000000 ])
    }

    /// Set a bit to true.
    func testSetToTrue() {
        var packer = BytePacker()
        packer.add(true, at: 7)
        
        XCTAssertEqual(packer.bytes, [ 0b10000000 ])
    }

    /// Set a bit to false.
    func testSetToFalse() {
        var packer = BytePacker()
        packer.add(false, at: 7)
        
        XCTAssertEqual(packer.bytes, [ 0b00000000 ])
    }
    
    /// Setting a bit twice starts a new byte.
    func testSetSameBit() {
        var packer = BytePacker()
        packer.add(true, at: 7)
        packer.add(true, at: 7)
        
        XCTAssertEqual(packer.bytes, [ 0b10000000, 0b10000000 ])
    }
    
    /// Setting a bit that overlaps a field starts a new byte.
    func testSetOverlapping() {
        var packer = BytePacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.add(true, at: 6)
        
        XCTAssertEqual(packer.bytes, [ 0b10100000, 0b01000000 ])
    }
    
    
    /// Signed values should still have all bits accessible.
    func testSignedValue() {
        let value: Int8 = -1
        var packer = BytePacker()
        packer.add(value, length: 8)
        
        XCTAssertEqual(packer.bytes, [ 0b11111111 ])
    }
    
}
