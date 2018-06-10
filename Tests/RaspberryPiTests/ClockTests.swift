//
//  ClockTests.swift
//  RaspberryPiTests
//
//  Created by Scott James Remnant on 6/6/18.
//

import XCTest

@testable import RaspberryPi

class ClockTests : XCTestCase {

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


    // MARK: Collection conformance

    /// Test that the collection implementation produces a correct count.
    func testCount() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clocks = Clock(registers: &registers)

        XCTAssertEqual(clocks.count, 5)
    }

    /// Test that the start index of the collection is the first general purpose 0.
    func testStartIndex() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clocks = Clock(registers: &registers)

        XCTAssertEqual(clocks.startIndex, .generalPurpose0)
    }

    /// Test that the end index of the collection is the invalid identifier.
    func testEndIndex() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clocks = Clock(registers: &registers)

        XCTAssertEqual(clocks.endIndex, .invalid)
    }

    /// Test that the collection implementation has correct indexes.
    func testIndexes() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clocks = Clock(registers: &registers)

        XCTAssertEqual(Array(clocks.indices), [ .generalPurpose0, .generalPurpose1, .generalPurpose2, .pcm, .pwm ])
    }


    // MARK: Specific clocks

    /// Test that when modifying the generalPurpose0 clock, the right registers are modified.
    func testGeneralPurpose0() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].isEnabled = true

        XCTAssertNotEqual(registers[14].control.rawValue, 0)
    }

    /// Test that when modifying the generalPurpose1 clock, the right registers are modified.
    func testGeneralPurpose1() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose1].isEnabled = true

        XCTAssertNotEqual(registers[15].control.rawValue, 0)
    }

    /// Test that when modifying the generalPurpose2 clock, the right registers are modified.
    func testGeneralPurpose2() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose2].isEnabled = true

        XCTAssertNotEqual(registers[16].control.rawValue, 0)
    }

    /// Test that when modifying the PCM clock, the right registers are modified.
    func testPCM() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.pcm].isEnabled = true

        XCTAssertNotEqual(registers[19].control.rawValue, 0)
    }

    /// Test that when modifying the PWM clock, the right registers are modified.
    func testPWM() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.pwm].isEnabled = true

        XCTAssertNotEqual(registers[19].control.rawValue, 0)
    }


    // MARK: Source

    /// Test that we can directly set the source field of the control register to oscillator.
    func testSetOscillatorSource() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .oscillator)
    }

    /// Test that we can directly set the source field of the control register to testdebug0.
    func testSetTestDebug0Source() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 2
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .testDebug0)
    }

    /// Test that we can directly set the source field of the control register to testdebug1.
    func testSetTestDebug1Source() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 3
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .testDebug1)
    }

    /// Test that we can directly set the source field of the control register to PLLA.
    func testSetPLLASource() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 4
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .plla)
    }

    /// Test that we can directly set the source field of the control register to PLLC.
    func testSetPLLCSource() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 5
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .pllc)
    }

    /// Test that we can directly set the source field of the control register to PLLD.
    func testSetPLLDSource() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 6
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .plld)
    }

    /// Test that we can directly set the source field of the control register to HDMI Auxillary.
    func testSetHDMIAuxillarySource() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 7
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .hdmiAux)
    }

    /// Test that we can directly set the source field of the control register to GND/none.
    func testSetGndSource() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].source, .none)
    }

    /// Test that invalid data in source field of the control register returns as GND/none.
    func testInvalidSource() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 4
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].isEnabled, true)
    }

    /// Test that the enabled bit defaults to false.
    func testNotIsEnabled() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].isEnabled, false)
    }

    /// Test that we can set the enabled bit in the control register.
    func testSetIsEnabled() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 7
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].isRunning, true)
    }

    /// Test that the enabled bit defaults to false.
    func testNotIsRunning() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 0
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 0)
    }

    /// Test that we can directly set the MASH field of the control register to 1-stage.
    func testSetOneStageMASH() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 1 << 9
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 1)
    }

    /// Test that we can directly set the MASH field of the control register to 2-stage.
    func testSetTwoStageMASH() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 2 << 9
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 2)
    }

    /// Test that we can directly set the MASH field of the control register to 3-stage.
    func testSetThreeStageMASH() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        withUnsafeMutablePointer(to: &registers[14].control) {
            $0.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee = 3 << 9
            }
        }

        XCTAssertEqual(clock[.generalPurpose0].mash, 3)
    }

    /// Test that setting the MASH field includes the clock password.
    func testSetMASHPassword() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(integer: 23, fractional: 503)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 23)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 503)
    }

    /// Test that we can initialize the highest divisor.
    func testInitializeHighest() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(integer: 4095, fractional: 4095)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 4095)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 4095)
    }

    /// Test that we can initialize a zero divisor.
    func testInitializeZero() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(integer: 0, fractional: 0)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 0)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 0)
    }

    /// Test that when we initialize, the field includes the clock password.
    func testInitializePassword() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 23.123)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 23)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 503)
    }

    /// Test that we can initialize a divisor from a whole number float.
    func testInitializeUpperBoundExact() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 98)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 98)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 0)
    }

    /// Test that we can initialize a divisor from a float close to the next whole number.
    func testInitializeUpperBoundAlmostNext() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 197.9999)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 197)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 4095)
    }

    /// Test that we can initialize a divisor from a float close to the highest number.
    func testInitializeUpperBoundHighest() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 4095.9999)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 4095)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 4095)
    }

    /// Test that we can initialize a divisor from a zero float.
    func testInitializeUpperBoundZero() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

        clock[.generalPurpose0].divisor = ClockDivisor(upperBound: 0)

        XCTAssertEqual(clock[.generalPurpose0].divisor.integer, 0)
        XCTAssertEqual(clock[.generalPurpose0].divisor.fractional, 0)
    }

    /// Test that when we initialize from a float, the field includes the clock password.
    func testInitializeUpperBoundPassword() {
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
        var registers = Array(repeating: Clock.Registers(), count: Clock.registerCount)
        let clock = Clock(registers: &registers)

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
