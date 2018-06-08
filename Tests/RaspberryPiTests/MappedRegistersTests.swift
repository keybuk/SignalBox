//
//  MappedRegistersTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/6/18.
//

import XCTest

@testable import RaspberryPi

final class Test : MappedRegisters {

    static let offset: UInt32 = 0x100000

    struct Registers {
        var first: Int32
        var second: Int32
    }

    var registers: UnsafeMutablePointer<Registers> = UnsafeMutablePointer(bitPattern: 0)!

}

class MappedRegistersTests : XCTestCase {

    /// Test that the bus address has the offset added to it.
    func testBusAddress() {
        XCTAssertEqual(Test.busAddress, RaspberryPi.peripheralBusAddress + 0x100000)
    }

    /// Test that the physical address has the offset added to it.
    func testAddress() {
        XCTAssertEqual(Test.address, RaspberryPi.periperhalAddress + 0x100000)
    }

}
