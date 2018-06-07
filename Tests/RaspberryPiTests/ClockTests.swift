//
//  ClockTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/6/18.
//

import XCTest

@testable import RaspberryPi

class ClockTests : XCTestCase {

    /// Test that two clocks have different offsets.
    func testOffset() {
        var registers = Clock.Registers()
        let pwmClock = Clock(clock: .pwm, registers: &registers)
        let pcmClock = Clock(clock: .pcm, registers: &registers)

        XCTAssertNotEqual(pwmClock.offset, pcmClock.offset)
    }


    // MARK: Source

    /// Test that we can directly set the source field of the control register to oscillator.
    func testSetOscillatorSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .oscillator

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 1)
    }

    /// Test that we can directly get the oscillator source field of the control register.
    func testGetOscillatorSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1
            }
        }

        XCTAssertEqual(clock.source, .oscillator)
    }

    /// Test that we can directly set the source field of the control register to testdebug0.
    func testSetTestDebug0Source() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .testDebug0

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 2)
    }

    /// Test that we can directly get the testdebug0 source field of the control register.
    func testGetTestDebug0Source() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 2
            }
        }

        XCTAssertEqual(clock.source, .testDebug0)
    }

    /// Test that we can directly set the source field of the control register to testdebug1.
    func testSetTestDebug1Source() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .testDebug1

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 3)
    }

    /// Test that we can directly get the testdebug1 source field of the control register.
    func testGetTestDebug1Source() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 3
            }
        }

        XCTAssertEqual(clock.source, .testDebug1)
    }

    /// Test that we can directly set the source field of the control register to PLLA.
    func testSetPLLASource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .plla

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 4)
    }

    /// Test that we can directly get the PLLA source field of the control register.
    func testGetPLLASource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 4
            }
        }

        XCTAssertEqual(clock.source, .plla)
    }

    /// Test that we can directly set the source field of the control register to PLLC.
    func testSetPLLCSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .pllc

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 5)
    }

    /// Test that we can directly get the PLLC source field of the control register.
    func testGetPLLCSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 5
            }
        }

        XCTAssertEqual(clock.source, .pllc)
    }

    /// Test that we can directly set the source field of the control register to PLLD.
    func testSetPLLDSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .plld

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 6)
    }

    /// Test that we can directly get the PLLD source field of the control register.
    func testGetPLLDSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 6
            }
        }

        XCTAssertEqual(clock.source, .plld)
    }

    /// Test that we can directly set the source field of the control register to HDMI Auxillary.
    func testSetHDMIAuxillarySource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .hdmiAux

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 7)
    }

    /// Test that we can directly get the HDMI Auxillary source field of the control register.
    func testGetHDMIAuxillarySource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 7
            }
        }

        XCTAssertEqual(clock.source, .hdmiAux)
    }

    /// Test that we can directly set the source field of the control register to GND/none.
    func testSetGndSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.source = .none

        XCTAssertEqual(registers.control.rawValue & ~(~0 << 4), 0)
    }

    /// Test that we can directly get the GND/none source field of the control register.
    func testGetGndSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock.source, .none)
    }

    /// Test that invalid data in source field of the control register returns as GND/none.
    func testInvalidSource() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        XCTAssertEqual(clock.source, .none)
    }

    /// Test that setting the source field includes the clock password.
    func testSetSourcePassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock.source = .oscillator

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: isEnabled

    /// Test that we can get the enabled bit from the control register.
    func testIsEnabled() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        XCTAssertEqual(clock.isEnabled, true)
    }

    /// Test that the enabled bit defaults to false.
    func testNotIsEnabled() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock.isEnabled, false)
    }

    /// Test that we can set the enabled bit in the control register.
    func testSetIsEnabled() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock.isEnabled = true

        XCTAssertEqual((registers.control.rawValue >> 4) & 1, 1)
    }

    /// Test that we can clear the enabled bit from the control register.
    func testClearIsEnabled() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        clock.isEnabled = false

        XCTAssertEqual((registers.control.rawValue >> 4) & 1, 0)
    }

    /// Test that when we enable the clock, the request includes the password.
    func testSetIsEnabledPassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock.isEnabled = true

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }

    /// Test that when we disable the clock, the request includes the password.
    func testClearIsEnabledPassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        clock.isEnabled = false

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: isRunning

    /// Test that we can get the busy bit from the control register.
    func testIsRunning() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 7
            }
        }

        XCTAssertEqual(clock.isRunning, true)
    }

    /// Test that the enabled bit defaults to false.
    func testNotIsRunning() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock.isRunning, false)
    }


    // MARK: MASH

    /// Test that we can directly set the MASH field of the control register to integer.
    func testSetIntegerMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.mash = .integer

        XCTAssertEqual((registers.control.rawValue >> 9) & ~(~0 << 2), 0)
    }

    /// Test that we can directly get the integer MASH field of the control register.
    func testGetIntegerMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock.mash, .integer)
    }

    /// Test that we can directly set the MASH field of the control register to 1-stage.
    func testSetOneStageMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.mash = .oneStage

        XCTAssertEqual((registers.control.rawValue >> 9) & ~(~0 << 2), 1)
    }

    /// Test that we can directly get the 1-stage MASH field of the control register.
    func testGetOneStageMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 9
            }
        }

        XCTAssertEqual(clock.mash, .oneStage)
    }

    /// Test that we can directly set the MASH field of the control register to 2-stage.
    func testSetTwoStageMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.mash = .twoStage

        XCTAssertEqual((registers.control.rawValue >> 9) & ~(~0 << 2), 2)
    }

    /// Test that we can directly get the 2-stage MASH field of the control register.
    func testGetTwoStageMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 2 << 9
            }
        }

        XCTAssertEqual(clock.mash, .twoStage)
    }

    /// Test that we can directly set the MASH field of the control register to 3-stage.
    func testSetThreeStageMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        // Corrupt the field to make sure the spare bits become zero.
        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = ~0
            }
        }

        clock.mash = .threeStage

        XCTAssertEqual((registers.control.rawValue >> 9) & ~(~0 << 2), 3)
    }

    /// Test that we can directly get the 3-stage MASH field of the control register.
    func testGetThreeStageMASH() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 3 << 9
            }
        }

        XCTAssertEqual(clock.mash, .threeStage)
    }

    /// Test that setting the MASH field includes the clock password.
    func testSetMASHPassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock.mash = .oneStage

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: Divisor initialization

    /// Test that we can initialize a divisor.
    func testInitialize() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(integer: 23, fractional: 503)

        XCTAssertEqual(clock.divisor.integer, 23)
        XCTAssertEqual(clock.divisor.fractional, 503)
    }

    /// Test that we can initialize the highest divisor.
    func testInitializeHighest() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(integer: 4095, fractional: 4095)

        XCTAssertEqual(clock.divisor.integer, 4095)
        XCTAssertEqual(clock.divisor.fractional, 4095)
    }

    /// Test that we can initialize a zero divisor.
    func testInitializeZero() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(integer: 0, fractional: 0)

        XCTAssertEqual(clock.divisor.integer, 0)
        XCTAssertEqual(clock.divisor.fractional, 0)
    }

    /// Test that when we initialize, the field includes the clock password.
    func testInitializePassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock.divisor = ClockDivisor(integer: 23, fractional: 503)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: Divisor initialization from float

    /// Test that we can initialize a divisor from a float.
    func testInitializeUpperBound() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(upperBound: 23.123)

        XCTAssertEqual(clock.divisor.integer, 23)
        XCTAssertEqual(clock.divisor.fractional, 503)
    }

    /// Test that we can initialize a divisor from a whole number float.
    func testInitializeUpperBoundExact() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(upperBound: 98)

        XCTAssertEqual(clock.divisor.integer, 98)
        XCTAssertEqual(clock.divisor.fractional, 0)
    }

    /// Test that we can initialize a divisor from a float close to the next whole number.
    func testInitializeUpperBoundAlmostNext() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(upperBound: 197.9999)

        XCTAssertEqual(clock.divisor.integer, 197)
        XCTAssertEqual(clock.divisor.fractional, 4095)
    }

    /// Test that we can initialize a divisor from a float close to the highest number.
    func testInitializeUpperBoundHighest() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(upperBound: 4095.9999)

        XCTAssertEqual(clock.divisor.integer, 4095)
        XCTAssertEqual(clock.divisor.fractional, 4095)
    }

    /// Test that we can initialize a divisor from a zero float.
    func testInitializeUpperBoundZero() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        clock.divisor = ClockDivisor(upperBound: 0)

        XCTAssertEqual(clock.divisor.integer, 0)
        XCTAssertEqual(clock.divisor.fractional, 0)
    }

    /// Test that when we initialize from a float, the field includes the clock password.
    func testInitializeUpperBoundPassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        clock.divisor = ClockDivisor(upperBound: 42.5)

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }

    // MARK: Divisor integer

    /// Test that we can set the integer component.
    func testSetInteger() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock.divisor.integer = 98

        XCTAssertEqual(clock.divisor.integer, 98)
    }

    /// Test that when we set the integer component, it doesn't alter the fractional.
    func testSetIntegerLeavesFractional() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock.divisor.integer = 98

        XCTAssertEqual(clock.divisor.fractional, 389)
    }

    /// Test that when we set the integer component, the field includes the password.
    func testSetIntegerPassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock.divisor.integer = 98

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
    }


    // MARK: Divisor fractional

    /// Test that we can set the fractional component.
    func testSetFractional() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock.divisor.fractional = 714

        XCTAssertEqual(clock.divisor.fractional, 714)
    }

    /// Test that when we set the fractional component, it doesn't alter the integer.
    func testSetFractionalLeavesInteger() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock.divisor.fractional = 714

        XCTAssertEqual(clock.divisor.integer, 74)
    }

    /// Test that when we set the fractional component, the field includes the password.
    func testSetFractionalPassword() {
        var registers = Clock.Registers()
        let clock = Clock(clock: .generalPurpose0, registers: &registers)

        withUnsafeMutablePointer(to: &registers.divisor) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = (74 << 12) | 389
            }
        }

        clock.divisor.fractional = 714

        withUnsafeMutablePointer(to: &registers.control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                XCTAssertEqual($0.pointee >> 24, 0x5a)
            }
        }
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

        control.insert(.busy)

        XCTAssertEqual((control.rawValue >> 7) & 1, 1)
    }

    /// Test that we can get the busy bit from the control register.
    func testGetBusy() {
        let control = ClockControl(rawValue: 1 << 7)

        XCTAssertTrue(control.contains(.busy))
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

        control = [ .mash(.integer) ]

        XCTAssertEqual((control.rawValue >> 9) & ~(~0 << 2), 0)
    }

    /// Test that we can set the MASH field of the control register to 1-stage via option set.
    func testOneStageMASH() {
        var control = ClockControl(rawValue: 0)

        control = [ .mash(.oneStage) ]

        XCTAssertEqual((control.rawValue >> 9) & ~(~0 << 2), 1)
    }

    /// Test that we can set the MASH field of the control register to 2-stage via option set.
    func testTwoStageMASH() {
        var control = ClockControl(rawValue: 0)

        control = [ .mash(.twoStage) ]

        XCTAssertEqual((control.rawValue >> 9) & ~(~0 << 2), 2)
    }

    /// Test that we can set the MASH field of the control register to 3-stage via option set.
    func testThreeStageMASH() {
        var control = ClockControl(rawValue: 0)

        control = [ .mash(.threeStage) ]

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
