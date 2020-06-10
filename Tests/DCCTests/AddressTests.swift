//
//  AddressTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 6/9/20.
//

import XCTest

import DCC

class AddressTests : XCTestCase {

    /// Check the binary pattenr of the broadcast address.
    func testBroadcastAddress() {
        let address = Address.broadcast

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.results, [ 0b00000000 ])
    }

    /// Check the binary pattern of a primary address.
    func testPrimaryAddress() {
        let address = Address.primary(3)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.results, [ 0b00000011 ])
    }

    /// Check the binary pattern of an extended address that fits in the second byte.
    func testSimpleExtendedAddress() {
        let address = Address.extended(210)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.results, [ 0b11000000, 0b11010010 ])
    }

    /// Check the binary pattern of an extended address that requires both bytes.
    func testBothBytesExtendedAddress() {
        let address = Address.extended(1250)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.results, [ 0b11000100, 0b11100010 ])
    }

    /// Check the binary pattern of an extended address in the overlapped space still contains two bytes.
    func testOverlappedExtendedAddress() {
        let address = Address.extended(3)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.results, [ 0b11000000, 0b00000011 ])
    }

    /// Check the binary pattern of an accessory address, including the one's complement part.
    func testAccessoryAddress() {
        let address = Address.accessory(310)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.results, [ 0b10100110, 0b10010000 ])
        XCTAssertEqual(packer.bitsRemaining, 4)
    }

    /// Check the binary pattern of an extended accessory (signal) address.
    func testSignalAddress() {
        let address = Address.signal(1134)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.results, [ 0b10100011, 0b00110101 ])
    }

    /// Check that two primary addresses of the same values are equal.
    func testSameAddresses() {
        let address1 = Address.primary(3)
        let address2 = Address.primary(3)

        XCTAssertEqual(address1, address2)
    }

    /// Check that two primary addresses of the different values are not equal.
    func testDifferentAddresses() {
        let address1 = Address.primary(3)
        let address2 = Address.primary(125)

        XCTAssertNotEqual(address1, address2)
    }

    /// Check that a primary and extended address of the same value are not equal.
    func testAddressInequatability() {
        let primaryAddress = Address.primary(3)
        let extendedAddress = Address.extended(3)

        XCTAssertNotEqual(primaryAddress, extendedAddress)
    }

    /// Check that primary addresses are comparable.
    func testPrimaryComparable() {
        let address1 = Address.primary(3)
        let address2 = Address.primary(125)

        XCTAssertTrue(address1 < address2)
    }

    /// Check that extended addresses sort after primary addresses.
    func testPrimaryLessThanExtended() {
        let address1 = Address.primary(125)
        let address2 = Address.extended(3)

        XCTAssertTrue(address1 < address2)
    }

    /// Check that extended addresses are comparable.
    func testExtendedComparable() {
        let address1 = Address.extended(3)
        let address2 = Address.extended(125)

        XCTAssertTrue(address1 < address2)
    }

    /// Check that accessory addresses are comparable.
    func testAccessoryComparable() {
        let address1 = Address.accessory(140)
        let address2 = Address.accessory(310)

        XCTAssertTrue(address1 < address2)
    }

    /// Check that signal addresses are comparable.
    func testSignalComparable() {
        let address1 = Address.signal(650)
        let address2 = Address.signal(1134)

        XCTAssertTrue(address1 < address2)
    }

}
