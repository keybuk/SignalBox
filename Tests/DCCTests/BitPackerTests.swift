//
//  BitPackerTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/15/18.
//

import XCTest

import DCC


class BitPackerTests: XCTestCase {
    
    /// Add a value at the top of a byte.
    func testStartOfByte() {
        var packer = BitPacker()
        packer.add(0b1111, at: 7, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b11110000 ])
    }
    
    /// Add a value in the middle of a byte.
    func testMiddleOfByte() {
        var packer = BitPacker()
        packer.add(0b1111, at: 5, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b00111100 ])
    }
    
    /// Add a value at the end of a byte.
    func testEndOfByte() {
        var packer = BitPacker()
        packer.add(0b1111, at: 3, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b00001111 ])
    }
    
    /// Add consecutive values within a byte.
    func testMultipleValues() {
        var packer = BitPacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.add(0b1111, at: 3, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10101111 ])
    }
    
    /// Add a new value at the top of a byte.
    func testValueStartsNewByte() {
        var packer = BitPacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.add(0b1111, at: 7, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10100000, 0b11110000 ])
    }
    
    /// Adding an overlapping value starts a new byte.
    func testOverlappingValue() {
        var packer = BitPacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.add(0b1111, at: 5, length: 4)
        
        XCTAssertEqual(packer.bytes, [ 0b10100000, 0b00111100 ])
    }
    
    /// Adding a value can extend into a new byte.
    func testExtendingValue() {
        var packer = BitPacker()
        packer.add(0b10, at: 7, length: 2)
        packer.add(0b11111111, at: 5, length: 8)
        
        XCTAssertEqual(packer.bytes, [ 0b10111111, 0b11000000 ])
    }
    
    /// Add a value that is longer than a byte.
    func testLongValue() {
        var packer = BitPacker()
        packer.add(0b11000011_11000011, at: 7, length: 16)
        
        XCTAssertEqual(packer.bytes, [ 0b011000011, 0b11000011 ])
    }
    
    /// Set a bit to true.
    func testSet() {
        var packer = BitPacker()
        packer.set(true, at: 7)
        
        XCTAssertEqual(packer.bytes, [ 0b10000000 ])
    }

    /// Set a bit to false.
    func testSetToFalse() {
        var packer = BitPacker()
        packer.set(false, at: 7)
        
        XCTAssertEqual(packer.bytes, [ 0b00000000 ])
    }
    
    /// Setting a bit twice starts a new byte.
    func testSetSameBit() {
        var packer = BitPacker()
        packer.set(true, at: 7)
        packer.set(true, at: 7)
        
        XCTAssertEqual(packer.bytes, [ 0b10000000, 0b10000000 ])
    }
    
    /// Setting a bit that overlaps a field starts a new byte.
    func testSetOverlapping() {
        var packer = BitPacker()
        packer.add(0b1010, at: 7, length: 4)
        packer.set(true, at: 6)
        
        XCTAssertEqual(packer.bytes, [ 0b10100000, 0b01000000 ])
    }
    
    /// Signed values should still have all bits accessible.
    func testSignedValue() {
        let value: Int8 = -1
        var packer = BitPacker()
        packer.add(value, at: 7, length: 8)
        
        XCTAssertEqual(packer.bytes, [ 0b11111111 ])
    }
    
}
