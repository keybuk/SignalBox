//
//  MappedRegistersTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/6/18.
//

import XCTest

@testable import RaspberryPi

final class Test : MappedRegisters {

    var offset: UInt32 = 0

    struct Registers {
        var first: Int32
        var second: Int32
    }

    var registers: UnsafeMutablePointer<Test.Registers>!

}

class MappedRegistersTests : XCTestCase {

    /// Test that the bus address has the offset added to it.
    func testBusAddress() {
        let test = Test()
        test.offset = 0x100000

        XCTAssertEqual(test.busAddress, RaspberryPi.peripheralBusAddress + 0x100000)
    }

    /// Test that the physical address has the offset added to it.
    func testAddress() {
        let test = Test()
        test.offset = 0x100000

        XCTAssertEqual(test.address, RaspberryPi.periperhalAddress + 0x100000)
    }

    /// Test that when the offset is on a page boundary, the map address matches.
    func testAddressOnPageBoundary() {
        let test = Test()
        test.offset = 0x100000

        XCTAssertEqual(test.mapAddress, RaspberryPi.periperhalAddress + 0x100000)
    }

    /// Test that when the offset is not on a page boundary, the map address is adjusted to one.
    func testAddressNotOnPageBoundary() {
        let test = Test()
        test.offset = 0x1000ff

        XCTAssertEqual(test.mapAddress, RaspberryPi.periperhalAddress + 0x100000)
    }

    /// Test that when the offset is on a page boundary, the map offset is zero.
    func testOffsetOnPageBoundary() {
        let test = Test()
        test.offset = 0x100000

        XCTAssertEqual(test.mapOffset, 0)
    }

    /// Test that when the offset is not on a page boundary, the map offset is the difference.
    func testOffsetNotOnPageBoundary() {
        let test = Test()
        test.offset = 0x10000ff

        XCTAssertEqual(test.mapOffset, 0xff)
    }

    /// Test that when the offset is on a page boundary, the map size rounds up to a page.
    func testSizeOnPageBoundary() {
        let test = Test()
        test.offset = 0x100000

        XCTAssertEqual(test.mapSize, Int(clamping: PAGE_SIZE))
    }

    /// Test that when the offset is not on a page boundary, the map size still rounds up to a page.
    func testSizeNotOnPageBoundary() {
        let test = Test()
        test.offset = 0x1000ff

        XCTAssertEqual(test.mapSize, Int(clamping: PAGE_SIZE))
    }

    /// Test that when the offset is right before a page boundary, the map size becomes two pages to fit.
    func testSizeAcrossPageBoundary() {
        let test = Test()
        test.offset = 0x100000 + UInt32(clamping: PAGE_SIZE) - 1

        XCTAssertEqual(test.mapSize, Int(clamping: PAGE_SIZE) * 2)
    }

}
