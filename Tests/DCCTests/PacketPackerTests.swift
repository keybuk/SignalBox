//
//  PacketPackerTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 11/16/19.
//

import XCTest

import DCC

class PacketPackerTests: XCTestCase {

    /// Test that we can add a single byte.
    func testSingleByte() {
        var packer = PacketPacker(packer: BitPacker<UInt32>())
        packer.add(0b10101100, length: 8)

        XCTAssertEqual(packer.packedValues, [0b0_10101100_0_10101100_1 << 13])
    }

    /// Test that we can add two bytes, and the error detection bit is an XOR of both.
    func testTwoBytes() {
        var packer = PacketPacker(packer: BitPacker<UInt32>())
        packer.add(0b10101100, length: 8)
        packer.add(0b01010110, length: 8)

        XCTAssertEqual(packer.packedValues, [0b0_10101100_0_01010110_0_11111010_1 << 4])
    }

    /// Test that we can add values across the byte boundary, and the byte separator bit is inserted between.
    func testValueAcrossByte() {
        var packer = PacketPacker(packer: BitPacker<UInt32>())
        packer.add(0b1010, length: 4)
        packer.add(0b11000101, length: 8)
        packer.add(0b0110, length: 4)

        XCTAssertEqual(packer.packedValues, [0b0_10101100_0_01010110_0_11111010_1 << 4])
    }

}
