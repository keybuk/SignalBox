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

        XCTAssertEqual(packer.packedValues, [ 0b00000000 ])
    }

    /// Check the binary pattern of a primary address.
    func testPrimaryAddress() {
        let address = Address.primary(3)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b00000011 ])
    }

    /// Check the binary pattern of an extended address that fits in the second byte.
    func testSimpleExtendedAddress() {
        let address = Address.extended(210)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b11000000, 0b11010010 ])
    }

    /// Check the binary pattern of an extended address that requires both bytes.
    func testBothBytesExtendedAddress() {
        let address = Address.extended(1250)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b11000100, 0b11100010 ])
    }

    /// Check that zero is accepted as an extended address and that the binary pattern is correct, and not confused with broadcast.
    func testZeroExtendedAddress() {
        let address = Address.extended(0)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b11000000, 0b00000000 ])
    }

    /// Check the binary pattern of an extended address in the overlapped space still contains two bytes.
    func testOverlappedExtendedAddress() {
        let address = Address.extended(3)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b11000000, 0b00000011 ])
    }

    /// Check the binary pattern of an accessory address, including the one's complement part.
    func testAccessoryAddress() {
        let address = Address.accessory(310)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b10100110, 0b10010000 ])
        XCTAssertEqual(packer.bitsRemaining, 4)
    }

    /// Check the binary pattern of the accessory broadcast address.
    func testAccessoryBroadcastAddress() {
        let address = Address.accessoryBroadcast

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b10111111, 0b10000000 ])
        XCTAssertEqual(packer.bitsRemaining, 4)
    }

    /// Check the binary pattern of an extended accessory (signal) address.
    func testSignalAddress() {
        let address = Address.signal(1134)

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b10100011, 0b01000101 ])
    }

    /// Check the binary pattern of the extended accessory broadcast address.
    func testSignalBroadcastAddress() {
        let address = Address.signalBroadcast

        var packer = BitPacker<UInt8>()
        packer.add(address)

        XCTAssertEqual(packer.packedValues, [ 0b10111111, 0b00000111 ])
    }

    /// Check that two broadcast addresses are equal.
    func testBroadcastSame() {
        XCTAssertEqual(Address.broadcast, Address.broadcast)
    }

    /// Check that two primary addresses of the same values are equal.
    func testSameAddresses() {
        XCTAssertEqual(Address.primary(3), Address.primary(3))
    }

    /// Check that two primary addresses of the different values are not equal.
    func testDifferentAddresses() {
        XCTAssertNotEqual(Address.primary(3), Address.primary(125))
    }

    /// Check that a primary and extended address of the same value are not equal.
    func testPrimaryExtendedPartition() {
        XCTAssertNotEqual(Address.primary(3), Address.extended(3))
    }

    /// Check that primary addresses are comparable.
    func testPrimaryComparable() {
        XCTAssertLessThan(Address.primary(3), Address.primary(125))
    }

    /// Check that extended addresses sort after primary addresses.
    func testPrimaryLessThanExtended() {
        XCTAssertLessThan(Address.primary(125), Address.extended(3))
    }

    /// Check that broadcast addresses are less than any other.
    func testBroadcastLowest() {
        XCTAssertLessThan(Address.broadcast, Address.primary(125))
        XCTAssertLessThan(Address.broadcast, Address.extended(1250))
        XCTAssertLessThan(Address.broadcast, Address.accessory(310))
        XCTAssertLessThan(Address.broadcast, Address.signal(1134))
    }

    /// Check that extended addresses are comparable.
    func testExtendedComparable() {
        XCTAssertLessThan(Address.extended(3), Address.extended(125))
    }

    /// Check that an accessory and extended accessory address of the same value are not equal.
    func testAccessoryPartition() {
        XCTAssertNotEqual(Address.accessory(140), Address.signal(140))
    }

    /// Check that accessory addresses are comparable.
    func testAccessoryComparable() {
        XCTAssertLessThan(Address.accessory(140), Address.accessory(310))
    }

    /// Check that accessory broadcast addresses are greater than accessory addresses.
    func testAccessoryBroadcastSort() {
        XCTAssertLessThan(Address.accessory(310), Address.accessoryBroadcast)
    }

    /// Check that signal addresses are comparable.
    func testSignalComparable() {
        XCTAssertLessThan(Address.signal(650), Address.signal(1134))
    }

    /// Check that accessory addresses sort earlier than signal addresses.
    func testAccessoryLessThanSignal() {
        XCTAssertLessThan(Address.accessory(310), Address.signal(113))
    }

    /// Check that extended accessory broadcast addresses are greater than extended accessory addresses.
    func testSignalBroadcastSort() {
        XCTAssertLessThan(Address.signal(1134), Address.signalBroadcast)
    }

    // MARK: description tests

    /// Check that we can turn a primary address into a string.
    func testPrimaryString() {
        let address = Address.primary(3)

        XCTAssertEqual("\(address)", "3")
    }

    /// Check that we can turn an extended address into a string and it's zero-padded to distinguish from a primary.
    func testExtendedString() {
        let address = Address.extended(3)

        XCTAssertEqual("\(address)", "0003")
    }

}
