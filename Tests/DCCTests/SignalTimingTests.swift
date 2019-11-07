//
//  SignalTimingTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/19/18.
//

import XCTest

import DCC

class SignalTimingTests : XCTestCase {
    
    // MARK: 1µs tests
    
    /// Test that when we use a pulseWidth of 1µs, the length of a one bit is 58 pulses.
    func testMicrosecondOneBit() {
        let timing = try! SignalTiming(pulseWidth: 1)
        XCTAssertEqual(timing.oneBitLength, 58)
    }
    
    /// Test that when we use a pulseWidth of 1µs, the length of a zero bit is 100 pulses.
    func testMicrosecondZeroBit() {
        let timing = try! SignalTiming(pulseWidth: 1)
        XCTAssertEqual(timing.zeroBitLength, 100)
    }
    
    /// Test that when we use a pulseWidth of 1µs, the length of the RailCom start delay is 26 pulses.
    func testMicrosecondRailComDelay() {
        let timing = try! SignalTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComDelayLength, 26)
    }
    
    /// Test that when we use a pulseWidth of 1µs, the length of a RailCom cutout is 454 pulses.
    func testMicrosecondRailCom() {
        let timing = try! SignalTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComLength, 454)
    }

    /// Test that when we use a pulseWidth of 1µs, RailCom requires 4 one bits.
    func testMicrosecondRailComCount() {
        let timing = try! SignalTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComCount, 4)
    }


    // MARK: 0.1µs tests

    /// Test that when we use a pulseWidth of 0.1µs, the length of a one bit is 580 pulses.
    func testTenthOneBit() {
        let timing = try! SignalTiming(pulseWidth: 0.1)
        XCTAssertEqual(timing.oneBitLength, 580)
    }

    /// Test that when we use a pulseWidth of 0.1µs, the length of a zero bit is 1000 pulses.
    func testTenthZeroBit() {
        let timing = try! SignalTiming(pulseWidth: 0.1)
        XCTAssertEqual(timing.zeroBitLength, 1000)
    }

    /// Test that when we use a pulseWidth of 0.1µs, the length of the RailCom start delay is 260 pulses.
    func testTenthRailComDelay() {
        let timing = try! SignalTiming(pulseWidth: 0.1)
        XCTAssertEqual(timing.railComDelayLength, 260)
    }

    /// Test that when we use a pulseWidth of 0.1µs, the length of a RailCom cutout is 4540 pulses.
    func testTenthRailCom() {
        let timing = try! SignalTiming(pulseWidth: 0.1)
        XCTAssertEqual(timing.railComLength, 4540)
    }

    /// Test that when we use a pulseWidth of 0.1µs, RailCom requires 4 one bits.
    func testTenthRailComCount() {
        let timing = try! SignalTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComCount, 4)
    }

    
    // MARK: 10µs tests

    /// Test that when we use a pulseWidth of 10µs, the length of a one bit is 6 pulses (60µs).
    func testTenOneBit() {
        let timing = try! SignalTiming(pulseWidth: 10)
        XCTAssertEqual(timing.oneBitLength, 6)
    }
    
    /// Test that when we use a pulseWidth of 10µs, the length of a zero bit is 10 pulses (100µs).
    func testTenZeroBit() {
        let timing = try! SignalTiming(pulseWidth: 10)
        XCTAssertEqual(timing.zeroBitLength, 10)
    }
    
    /// Test that when we use a pulseWidth of 10µs, the length of the RailCom start delay is 3 pulses (30µs).
    func testTenRailComDelay() {
        let timing = try! SignalTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComDelayLength, 3)
    }
    
    /// Test that when we use a pulseWidth of 10µs, the length of a RailCom cutout is 46 pulses (460µs).
    func testTenRailCom() {
        let timing = try! SignalTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComLength, 46)
    }
    
    /// Test that when we use a pulseWidth of 10µs, RailCom requires 4 one bits.
    func testTenRailComCount() {
        let timing = try! SignalTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComCount, 4)
    }

    
    // MARK: 14.5µs tests
    
    /// Test that when we use a pulseWidth of 14.5µs, the length of a one bit is 4 pulses (58µs).
    func testGoldilocksOneBit() {
        let timing = try! SignalTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.oneBitLength, 4)
    }
    
    /// Test that when we use a pulseWidth of 14.5µs, the length of a zero bit is 7 pulses (101.5µs).
    func testGoldilocksZeroBit() {
        let timing = try! SignalTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.zeroBitLength, 7)
    }
    
    /// Test that when we use a pulseWidth of 14.5µs, the length of the RailCom start delay is 2 pulses (29µs).
    func testGoldilocksRailComDelay() {
        let timing = try! SignalTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.railComDelayLength, 2)
    }
    
    /// Test that when we use a pulseWidth of 14.5µs, the length of a RailCom cutout is 32 pulses (464µs).
    func testGoldilocksRailCom() {
        let timing = try! SignalTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.railComLength, 32)
    }
    
    /// Test that when we use a pulseWidth of 14.5µs, RailCom requires 4 one bits.
    func testGoldilocksRailComCount() {
        let timing = try! SignalTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.railComCount, 4)
    }


    // MARK: 29µs tests

    /// Test that when we use a pulseWidth of 29µs, the length of a one bit is 2 pulses (58µs).
    func testDoubleOneBit() {
        let timing = try! SignalTiming(pulseWidth: 29)
        XCTAssertEqual(timing.oneBitLength, 2)
    }

    /// Test that when we use a pulseWidth of 29µs, the length of a zero bit is 4 pulses (116µs).
    func testDoubleZeroBit() {
        // This tests the code to correct simple rounding, since the rounded value of 116/29 would
        // give a result of 87µs which is outside the range.
        let timing = try! SignalTiming(pulseWidth: 29)
        XCTAssertEqual(timing.zeroBitLength, 4)
    }

    /// Test that when we use a pulseWidth of 29µs, the length of the RailCom start delay is 1 pulse (29µs).
    func testDoubleRailComDelay() {
        let timing = try! SignalTiming(pulseWidth: 29)
        XCTAssertEqual(timing.railComDelayLength, 1)
    }

    /// Test that when we use a pulseWidth of 29µs, the length of a RailCom cutout is 16 pulses (464µs).
    func testDoubleRailCom() {
        let timing = try! SignalTiming(pulseWidth: 29)
        XCTAssertEqual(timing.railComLength, 16)
    }

    /// Test that when we use a pulseWidth of 29µs, RailCom requires 4 one bits.
    func testDoubleRailComCount() {
        let timing = try! SignalTiming(pulseWidth: 29)
        XCTAssertEqual(timing.railComCount, 4)
    }


    // MARK: 7µs tests

    /// Test that when we use a pulseWidth of 7µs, the length of a one bit is 8 pulses (56µs).
    func testSevenOneBit() {
        let timing = try! SignalTiming(pulseWidth: 7)
        XCTAssertEqual(timing.oneBitLength, 8)
    }

    /// Test that when we use a pulseWidth of 7µs, the length of a zero bit is 14 pulses (98µs).
    func testSevenZeroBit() {
        let timing = try! SignalTiming(pulseWidth: 7)
        XCTAssertEqual(timing.zeroBitLength, 14)
    }

    /// Test that when we use a pulseWidth of 7µs, the length of the RailCom start delay is 4 pulses (28µs).
    func testSevenRailComDelay() {
        let timing = try! SignalTiming(pulseWidth: 7)
        XCTAssertEqual(timing.railComDelayLength, 4)
    }

    /// Test that when we use a pulseWidth of 7µs, the length of a RailCom cutout is 65 pulses (455µs).
    func testSevenRailCom() {
        let timing = try! SignalTiming(pulseWidth: 7)
        XCTAssertEqual(timing.railComLength, 65)
    }

    /// Test that when we use a pulseWidth of 7µs, RailCom requires 5 one bits because it has an odd number of pulses for the cutout and we can only output full one bits.
    func testSevenRailComCount() {
        let timing = try! SignalTiming(pulseWidth: 7)
        XCTAssertEqual(timing.railComCount, 5)
    }

    
    // MARK: failing tests
    
    /// Test that when we try and use a pulse width of 25µs, the initializer throws an error because
    /// this wouldn't produce an acceptable one bit duration.
    func testFailOneBit() {
        XCTAssertThrowsError(try SignalTiming(pulseWidth: 25))
    }
    
    /// Test that when we try and use a pulse width of 58µs, the initializer throws an error because
    /// this wouldn't produce an acceptable RailCom cutout delay.
    func testFailRailComDelay() {
        XCTAssertThrowsError(try SignalTiming(pulseWidth: 58))
    }

}
