//
//  ClockTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/6/18.
//

import XCTest

@testable import RaspberryPi

class ClockLayoutTests : XCTestCase {
    
    // MARK: Layout
    
    /// Test that the layout of the Registers struct matches hardware.
    func testRegistersLayout() {
        XCTAssertEqual(MemoryLayout<Clock.Registers>.size, 0x08)
        XCTAssertEqual(MemoryLayout<ClockControl>.size, 0x04)
        XCTAssertEqual(MemoryLayout<ClockDivisor>.size, 0x04)
        
        #if swift(>=4.1.5)
        XCTAssertEqual(MemoryLayout.offset(of: \Clock.Registers.control), 0x00)
        XCTAssertEqual(MemoryLayout.offset(of: \Clock.Registers.divisor), 0x04)
        #endif
    }

}


class ClockTests : XCTestCase {
    
    var registers: [Clock.Registers] = []
    var clock: Clock!
    
    override func setUp() {
        registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        clock = Clock(registers: &registers)
    }
    
    override func tearDown() {
        registers.removeAll()
        clock = nil
    }

    
    // MARK: Collection conformance

    /// Test that the collection implementation produces a correct count.
    func testCount() {
        XCTAssertEqual(clock.count, 5)
    }

    /// Test that the start index of the collection is the first general purpose 0.
    func testStartIndex() {
        XCTAssertEqual(clock.startIndex, .generalPurpose0)
    }

    /// Test that the end index of the collection is the invalid identifier.
    func testEndIndex() {
        XCTAssertEqual(clock.endIndex, .invalid)
    }

    /// Test that the collection implementation has correct indexes.
    func testIndexes() {
        XCTAssertEqual(Array(clock.indices), [ .generalPurpose0, .generalPurpose1, .generalPurpose2, .pcm, .pwm ])
    }


    // MARK: Specific clocks

    /// Test that when modifying the generalPurpose0 clock, the right registers are modified.
    func testGeneralPurpose0() {
        clock[.generalPurpose0].isEnabled = true

        XCTAssertNotEqual(registers[14].control.rawValue, 0)
    }

    /// Test that when modifying the generalPurpose1 clock, the right registers are modified.
    func testGeneralPurpose1() {
        clock[.generalPurpose1].isEnabled = true

        XCTAssertNotEqual(registers[15].control.rawValue, 0)
    }

    /// Test that when modifying the generalPurpose2 clock, the right registers are modified.
    func testGeneralPurpose2() {
        clock[.generalPurpose2].isEnabled = true

        XCTAssertNotEqual(registers[16].control.rawValue, 0)
    }

    /// Test that when modifying the PCM clock, the right registers are modified.
    func testPCM() {
        clock[.pcm].isEnabled = true

        XCTAssertNotEqual(registers[19].control.rawValue, 0)
    }

    /// Test that when modifying the PWM clock, the right registers are modified.
    func testPWM() {
        clock[.pwm].isEnabled = true

        XCTAssertNotEqual(registers[19].control.rawValue, 0)
    }


    // MARK: Source

    /// Test that we can directly set the source field of the control register to oscillator.
    func testSetOscillatorSource() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .oscillator

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 1)
    }

    /// Test that we can directly get the oscillator source field of the control register.
    func testGetOscillatorSource() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .oscillator)
    }

    /// Test that we can directly set the source field of the control register to testdebug0.
    func testSetTestDebug0Source() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .testDebug0

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 2)
    }

    /// Test that we can directly get the testdebug0 source field of the control register.
    func testGetTestDebug0Source() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 2
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .testDebug0)
    }

    /// Test that we can directly set the source field of the control register to testdebug1.
    func testSetTestDebug1Source() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .testDebug1

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 3)
    }

    /// Test that we can directly get the testdebug1 source field of the control register.
    func testGetTestDebug1Source() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 3
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .testDebug1)
    }

    /// Test that we can directly set the source field of the control register to PLLA.
    func testSetPLLASource() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .plla

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 4)
    }

    /// Test that we can directly get the PLLA source field of the control register.
    func testGetPLLASource() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 4
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .plla)
    }

    /// Test that we can directly set the source field of the control register to PLLC.
    func testSetPLLCSource() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .pllc

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 5)
    }

    /// Test that we can directly get the PLLC source field of the control register.
    func testGetPLLCSource() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 5
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .pllc)
    }

    /// Test that we can directly set the source field of the control register to PLLD.
    func testSetPLLDSource() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .plld

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 6)
    }

    /// Test that we can directly get the PLLD source field of the control register.
    func testGetPLLDSource() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 6
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .plld)
    }

    /// Test that we can directly set the source field of the control register to HDMI Auxillary.
    func testSetHDMIAuxillarySource() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .hdmiAux

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 7)
    }

    /// Test that we can directly get the HDMI Auxillary source field of the control register.
    func testGetHDMIAuxillarySource() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 7
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .hdmiAux)
    }

    /// Test that we can directly set the source field of the control register to GND/none.
    func testSetGndSource() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].source = .none

        XCTAssertEqual(registers[14].control.rawValue & ~(~0 << 4), 0)
    }

    /// Test that we can directly get the GND/none source field of the control register.
    func testGetGndSource() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .none)
    }

    /// Test that invalid data in source field of the control register returns as GND/none.
    func testInvalidSource() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .none)
    }

    /// Test that setting the source field includes the clock password.
    func testSetSourcePassword() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock[.generalPurpose0].source = .oscillator

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: isEnabled

    /// Test that we can get the enabled bit from the control register.
    func testIsEnabled() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].isEnabled, true)
    }

    /// Test that the enabled bit defaults to false.
    func testNotIsEnabled() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].isEnabled, false)
    }

    /// Test that we can set the enabled bit in the control register.
    func testSetIsEnabled() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock[.generalPurpose0].isEnabled = true

        XCTAssertEqual((registers[14].control.rawValue >> 4) & 1, 1)
    }

    /// Test that we can clear the enabled bit from the control register.
    func testClearIsEnabled() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        clock[.generalPurpose0].isEnabled = false

        XCTAssertEqual((registers[14].control.rawValue >> 4) & 1, 0)
    }

    /// Test that when we enable the clock, the request includes the password.
    func testSetIsEnabledPassword() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock[.generalPurpose0].isEnabled = true

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }

    /// Test that when we disable the clock, the request includes the password.
    func testClearIsEnabledPassword() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        clock[.generalPurpose0].isEnabled = false

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: isRunning

    /// Test that we can get the busy bit from the control register.
    func testIsRunning() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 7
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].isRunning, true)
    }

    /// Test that the enabled bit defaults to false.
    func testNotIsRunning() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].isRunning, false)
    }


    // MARK: MASH

    /// Test that we can directly set the MASH field of the control register to integer.
    func testSetIntegerMASH() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].mash = 0

        XCTAssertEqual((registers[14].control.rawValue >> 9) & ~(~0 << 2), 0)
    }

    /// Test that we can directly get the integer MASH field of the control register.
    func testGetIntegerMASH() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 0)
    }

    /// Test that we can directly set the MASH field of the control register to 1-stage.
    func testSetOneStageMASH() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].mash = 1

        XCTAssertEqual((registers[14].control.rawValue >> 9) & ~(~0 << 2), 1)
    }

    /// Test that we can directly get the 1-stage MASH field of the control register.
    func testGetOneStageMASH() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 9
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 1)
    }

    /// Test that we can directly set the MASH field of the control register to 2-stage.
    func testSetTwoStageMASH() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].mash = 2

        XCTAssertEqual((registers[14].control.rawValue >> 9) & ~(~0 << 2), 2)
    }

    /// Test that we can directly get the 2-stage MASH field of the control register.
    func testGetTwoStageMASH() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 2 << 9
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 2)
    }

    /// Test that we can directly set the MASH field of the control register to 3-stage.
    func testSetThreeStageMASH() {
        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock[.generalPurpose0].mash = 3

        XCTAssertEqual((registers[14].control.rawValue >> 9) & ~(~0 << 2), 3)
    }

    /// Test that we can directly get the 3-stage MASH field of the control register.
    func testGetThreeStageMASH() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 3 << 9
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 3)
    }

    /// Test that setting the MASH field includes the clock password.
    func testSetMASHPassword() {
        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock[.generalPurpose0].mash = 1

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: Divisor initialization

    /// Test that we can initialize a divisor.
    func testInitialize() {
        clock[.generalPurpose0].divisor = ClockDivisor(integer: 23, fractional: 503)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 23)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 503)
    }

    /// Test that we can initialize the highest divisor.
    func testInitializeHighest() {
        clock[.generalPurpose0].divisor = ClockDivisor(integer: 4095, fractional: 4095)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 4095)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 4095)
    }

    /// Test that we can initialize a zero divisor.
    func testInitializeZero() {
        clock[.generalPurpose0].divisor = ClockDivisor(integer: 0, fractional: 0)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 0)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 0)
    }

    /// Test that when we initialize, the field includes the clock password.
    func testInitializePassword() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock[.generalPurpose0].divisor = ClockDivisor(integer: 23, fractional: 503)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: Divisor initialization from float

    /// Test that we can initialize a divisor from a float.
    func testInitializeUpperBound() {
        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 23.123)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 23)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 503)
    }

    /// Test that we can initialize a divisor from a whole number float.
    func testInitializeUpperBoundExact() {
        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 98)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 98)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 0)
    }

    /// Test that we can initialize a divisor from a float close to the next whole number.
    func testInitializeUpperBoundAlmostNext() {
        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 197.9999)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 197)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 4095)
    }

    /// Test that we can initialize a divisor from a float close to the highest number.
    func testInitializeUpperBoundHighest() {
        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 4095.9999)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 4095)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 4095)
    }

    /// Test that we can initialize a divisor from a zero float.
    func testInitializeUpperBoundZero() {
        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 0)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 0)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 0)
    }

    /// Test that when we initialize from a float, the field includes the clock password.
    func testInitializeUpperBoundPassword() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 42.5)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }

    // MARK: Divisor integer

    /// Test that we can set the integer component.
    func testSetInteger() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock[.generalPurpose0].divisor.integer = 98

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 98)
    }

    /// Test that when we set the integer component, it doesn't alter the fractional.
    func testSetIntegerLeavesFractional() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock[.generalPurpose0].divisor.integer = 98

        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 389)
    }

    /// Test that when we set the integer component, the field includes the password.
    func testSetIntegerPassword() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock[.generalPurpose0].divisor.integer = 98

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: Divisor fractional

    /// Test that we can set the fractional component.
    func testSetFractional() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock[.generalPurpose0].divisor.fractional = 714

        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 714)
    }

    /// Test that when we set the fractional component, it doesn't alter the integer.
    func testSetFractionalLeavesInteger() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock[.generalPurpose0].divisor.fractional = 714

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 74)
    }

    /// Test that when we set the fractional component, the field includes the password.
    func testSetFractionalPassword() {
        withUnsafeMutablePointer(to: &registers[14].divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock[.generalPurpose0].divisor.fractional = 714

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }
    
    
    // MARK: Divisor floatValue
    
    /// Test that can we get the float value of a divisor.
    func testDivisorFloatValue() {
        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 28.3)
        
        XCTAssertEqual(clock[.generalPurpose0].divisor.floatValue, 28.2998, accuracy: 0.0001)
    }

    
    // MARK: Divisor string value
    
    /// Test that can we turn the divisor into a string.
    func testDivisorDescriptioon() {
        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 28.3)

        let description = "\(clock[.generalPurpose0].divisor)"
        XCTAssertEqual(description[..<description.index(description.startIndex, offsetBy: 7)], "28.2998")
    }


    // MARK: configure(forCycle:mash:)

    /// A cycle of 10µs should be possible.
    func testConfigure10µsPossible() {
        let cycle = clock[.pwm].configure(forCycle: 10, mash: 0)

        XCTAssertNotNil(cycle)
    }

    /// A cycle of 10µs should be exactly possible.
    func testConfigure10µsExact() {
        let cycle = clock[.pwm].configure(forCycle: 10, mash: 0)

        XCTAssertEqual(cycle!, 10)
    }

    /// A cycle of 10µs should use the oscillator.
    func testConfigure10µsSource() {
        let _ = clock[.pwm].configure(forCycle: 10, mash: 0)

        XCTAssertEqual(clock[.pwm].source, .oscillator)
    }

    /// A cycle of 10µs should have an integer divisor of 192.
    func testConfigure10µsIntegerDivisor() {
        let _ = clock[.pwm].configure(forCycle: 10, mash: 0)

        XCTAssertEqual(clock[.pwm].divisor.integer, 192)
    }

    /// A cycle of 10µs should have an fractional divisor of 0 since we specified no mash.
    func testConfigure10µsFractionalDivisor() {
        let _ = clock[.pwm].configure(forCycle: 10, mash: 0)

        XCTAssertEqual(clock[.pwm].divisor.fractional, 0)
    }

    /// A cycle of 10µs should set the mash to 0.
    func testConfigure10µsMASH() {
        let _ = clock[.pwm].configure(forCycle: 10, mash: 0)

        XCTAssertEqual(clock[.pwm].mash, 0)
    }

    /// A cycle of 10µs with MASH should set the MASH.
    func testConfigure10µsWithMASH() {
        let _ = clock[.pwm].configure(forCycle: 10, mash: 1)

        XCTAssertEqual(clock[.pwm].mash, 1)
    }

    /// A cycle of 1µs should be possible using the PPLD.
    func testConfigure1µsPossible() {
        let cycle = clock[.pwm].configure(forCycle: 1, mash: 0)

        XCTAssertNotNil(cycle)
        XCTAssertEqual(cycle!, 1)
        XCTAssertEqual(clock[.pwm].mash, 0)
        XCTAssertEqual(clock[.pwm].source, .plld)
        XCTAssertEqual(clock[.pwm].divisor.integer, 500)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 0)
    }

    /// Without MASH, a cycle of 58µs should be possible with the oscillator, but not exact.
    func testConfigure58µsWithoutMASH() {
        let cycle = clock[.pwm].configure(forCycle: 58, mash: 0)

        XCTAssertNotNil(cycle)
        XCTAssertEqual(cycle!, 57.96875, accuracy: 0.00001)
        XCTAssertEqual(clock[.pwm].mash, 0)
        XCTAssertEqual(clock[.pwm].source, .oscillator)
        XCTAssertEqual(clock[.pwm].divisor.integer, 1113)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 0)
    }

    /// With MASH, a cycle of 58µs should be exactly possible with the oscillator.
    func testConfigure58µsWithMASH() {
        let cycle = clock[.pwm].configure(forCycle: 58, mash: 1)

        XCTAssertNotNil(cycle)
        XCTAssertEqual(cycle!, 58, accuracy: 0.00001)
        XCTAssertEqual(clock[.pwm].mash, 1)
        XCTAssertEqual(clock[.pwm].source, .oscillator)
        XCTAssertEqual(clock[.pwm].divisor.integer, 1113)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 2458)
    }

    /// Check that when a particular value is given without a MASH, the closest clock is preferred,
    /// but when a MASH is given, the one with the smaller divisor is preferred instead.
    func testPrefersAccuracyThenSmallerDivisor() {
        let _ = clock[.pwm].configure(forCycle: 4.453125, mash: 0)

        XCTAssertEqual(clock[.pwm].source, .plld)
        XCTAssertEqual(clock[.pwm].mash, 0)
        XCTAssertEqual(clock[.pwm].divisor.integer, 2226)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 0)

        let _ = clock[.pwm].configure(forCycle: 4.453125, mash: 1)
        XCTAssertEqual(clock[.pwm].source, .oscillator)
        XCTAssertEqual(clock[.pwm].mash, 1)
        XCTAssertEqual(clock[.pwm].divisor.integer, 85)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 2048)
    }

    /// Check that we can configure for the goldilocks bit duration of 14.5µs.
    func testConfigureGoldilocksCycle() {
        let cycle = clock[.pwm].configure(forCycle: 14.5, mash: 0)

        XCTAssertNotNil(cycle)

        XCTAssertEqual(cycle!, 14.48, accuracy: 0.01)

        XCTAssertEqual(clock[.pwm].source, .oscillator)
        XCTAssertEqual(clock[.pwm].mash, 0)
        XCTAssertEqual(clock[.pwm].divisor.integer, 278)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 0)
    }

    /// A cycle of 250µs should not be possible.
    func testConfigure250µsNotPossible() {
        let cycle = clock[.pwm].configure(forCycle: 250, mash: 0)

        XCTAssertNil(cycle)
    }

    /// A cycle of 0.001µs should not be possible without MASH.
    func testConfigureTinyNotPossible() {
        let cycle = clock[.pwm].configure(forCycle: 0.001, mash: 0)

        XCTAssertNil(cycle)
    }

    /// A cycle of 0.001µs should be possible with MASH.
    func testConfigureTinyPossibleWithMASH() {
        let cycle = clock[.pwm].configure(forCycle: 0.001, mash: 1)

        XCTAssertNotNil(cycle)
    }


    // MARK: configure(forFrequency:mash:)

    /// Check that we can configure for a target frequency.
    func testConfigureFrequencyForOscillator() {
        let frequency = clock[.pwm].configure(forFrequency: 4.8, mash: 0)

        XCTAssertNotNil(frequency)
        XCTAssertEqual(frequency!, 4.8, accuracy: 0.0001)
        XCTAssertEqual(clock[.pwm].source, .oscillator)
        XCTAssertEqual(clock[.pwm].mash, 0)
        XCTAssertEqual(clock[.pwm].divisor.integer, 4)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 0)
    }

    /// Check that we can configure for a target frequency that will need the PPLD and a MASH.
    func testConfigureFrequencyForPLLD() {
        let frequency = clock[.pwm].configure(forFrequency: 144, mash: 1)

        XCTAssertNotNil(frequency)
        XCTAssertEqual(frequency!, 144, accuracy: 0.01)
        XCTAssertEqual(clock[.pwm].source, .plld)
        XCTAssertEqual(clock[.pwm].mash, 1)
        XCTAssertEqual(clock[.pwm].divisor.integer, 3)
        XCTAssertEqual(clock[.pwm].divisor.fractional, 1934)
    }

}

class ClockControlTests : XCTestCase {

    /// Test that we can set the enabled bit.
    func testSetEnabled() {
        var control = ClockControl(rawValue: 0)

        control.insert(.enabled)

        XCTAssertEqual((control.rawValue >> 4) & 1, 1)
    }

    /// Test that we can get the enabled bit.
    func testGetEnabled() {
        let control = ClockControl(rawValue: 1 << 4)

        XCTAssertTrue(control.contains(.enabled))
    }

    /// Test that we can set the kill bit.
    func testSetKill() {
        var control = ClockControl(rawValue: 0)

        control.insert(.kill)

        XCTAssertEqual((control.rawValue >> 5) & 1, 1)
    }

    /// Test that we can get the kill bit.
    func testGetKill() {
        let control = ClockControl(rawValue: 1 << 5)

        XCTAssertTrue(control.contains(.kill))
    }

    /// Test that we can set the busy bit.
    func testSetBusy() {
        var control = ClockControl(rawValue: 0)

        control.insert(.running)

        XCTAssertEqual((control.rawValue >> 7) & 1, 1)
    }

    /// Test that we can get the busy bit from the control register.
    func testGetBusy() {
        let control = ClockControl(rawValue: 1 << 7)

        XCTAssertTrue(control.contains(.running))
    }

    /// Test that we can set the flip bit in the control register.
    func testSetInvertOutput() {
        var control = ClockControl(rawValue: 0)

        control.insert(.invertOutput)

        XCTAssertEqual((control.rawValue >> 8) & 1, 1)
    }

    /// Test that we can get the flip bit from the control register.
    func testGetInvertOutput() {
        let control = ClockControl(rawValue: 1 << 8)

        XCTAssertTrue(control.contains(.invertOutput))
    }

    /// Test that we can set the source field of the control register to oscillator via option set.
    func testOscillatorSource() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.oscillator) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 1)
    }

    /// Test that we can set the source field of the control register to testdebug1 via option set.
    func testTestDebug1Source() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.testDebug1) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 3)
    }

    /// Test that we can set the source field of the control register to testdebug0 via option set.
    func testTestDebug0Source() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.testDebug0) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 2)
    }

    /// Test that we can set the source field of the control register to PLLA via option set.
    func testPLLASource() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.plla) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 4)
    }

    /// Test that we can set the source field of the control register to PLLC via option set.
    func testPLLCSource() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.pllc) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 5)
    }

    /// Test that we can set the source field of the control register to PLLD via option set.
    func testPLLDSource() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.plld) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 6)
    }

    /// Test that we can set the source field of the control register to HDMI Auxillary via option set.
    func testHDMIAuxillarySource() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.hdmiAux) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 7)
    }

    /// Test that we can set the source field of the control register to GND/none via option set.
    func testGndSource() {
        var control = ClockControl(rawValue: 0)

        control = [ .source(.none) ]

        XCTAssertEqual(control.rawValue & ~(~0 << 4), 0)
    }

    /// Test that we can set the MASH field of the control register to integer via option set.
    func testIntegerMASH() {
        var control = ClockControl(rawValue: 0)

        control = [ .mash(0) ]

        XCTAssertEqual((control.rawValue >> 9) & ~(~0 << 2), 0)
    }

    /// Test that we can set the MASH field of the control register to 1-stage via option set.
    func testOneStageMASH() {
        var control = ClockControl(rawValue: 0)

        control = [ .mash(1) ]

        XCTAssertEqual((control.rawValue >> 9) & ~(~0 << 2), 1)
    }

    /// Test that we can set the MASH field of the control register to 2-stage via option set.
    func testTwoStageMASH() {
        var control = ClockControl(rawValue: 0)

        control = [ .mash(2) ]

        XCTAssertEqual((control.rawValue >> 9) & ~(~0 << 2), 2)
    }

    /// Test that we can set the MASH field of the control register to 3-stage via option set.
    func testThreeStageMASH() {
        var control = ClockControl(rawValue: 0)

        control = [ .mash(3) ]

        XCTAssertEqual((control.rawValue >> 9) & ~(~0 << 2), 3)
    }

    
    // MARK: Password

    /// Test that setting a control register includes the clock password.
    func testPassword() {
        var control = ClockControl(rawValue: 0)

        // Reset the underlying value to a real 0
        withUnsafeMutablePointer(to: &control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        control = [ .enabled ]

        withUnsafeMutablePointer(to: &control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }

    /// Test that inserting into a control register includes the clock password.
    func testPasswordInserting() {
        var control = ClockControl(rawValue: 0)

        // Reset the underlying value to a real 0
        withUnsafeMutablePointer(to: &control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        control.insert(.enabled)

        withUnsafeMutablePointer(to: &control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }

    /// Test that removing from a control register includes the clock password.
    func testPasswordRemoving() {
        var control = ClockControl(rawValue: 0)

        // Reset the underlying value to a real 0
        withUnsafeMutablePointer(to: &control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        control.remove(.enabled)

        withUnsafeMutablePointer(to: &control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }

}
