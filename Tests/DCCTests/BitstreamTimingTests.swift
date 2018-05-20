//
//  BitstreamTimingTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/19/18.
//

import XCTest

import DCC

class BitstreamTimingTests: XCTestCase {
    
    // MARK: 1ms tests
    
    /// Test that when we use a pulseWidth of 1ms, the length of a one bit is 58 pulses.
    func testMicrosecondOneBit() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.oneBitLength, 58)
    }
    
    /// Test that when we use a pulseWidth of 1ms, the length of a zero bit is 100 pulses.
    func testMicrosecondZeroBit() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.zeroBitLength, 100)
    }
    
    /// Test that when we use a pulseWidth of 1ms, the length of the RailCom start delay is 26 pulses.
    func testMicrosecondRailComDelay() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComDelayLength, 26)
    }
    
    /// Test that when we use a pulseWidth of 1ms, the length of a RailCom cutout is 454 pulses.
    func testMicrosecondRailCom() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComLength, 454)
    }

    /// Test that when we use a pulseWidth of 1ms, RailCom requires 4 one bits.
    func testMicrosecondRailComCount() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComCount, 4)
    }

    /// Test that when we use a pulseWidth of 1ms, a preamble requires 18 one bits.
    func testMicrosecondPreambleCount() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.preambleCount, 18)
    }

    
    // MARK: 10ms tests

    /// Test that when we use a pulseWidth of 10ms, the length of a one bit is 6 pulses (60ms).
    func testTenMsOneBit() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.oneBitLength, 6)
    }
    
    /// Test that when we use a pulseWidth of 10ms, the length of a zero bit is 10 pulses (100ms).
    func testTenMsZeroBit() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.zeroBitLength, 10)
    }
    
    /// Test that when we use a pulseWidth of 10ms, the length of the RailCom start delay is 3 pulses (30ms).
    func testTenMsRailComDelay() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComDelayLength, 3)
    }
    
    /// Test that when we use a pulseWidth of 10ms, the length of a RailCom cutout is 46 pulses (460ms).
    func testTenMsRailCom() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComLength, 46)
    }
    
    /// Test that when we use a pulseWidth of 10ms, RailCom requires 4 one bits.
    func testTenMsRailComCount() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComCount, 4)
    }

    /// Test that when we use a pulseWidth of 10ms, a preamble requires 18 one bits.
    func testTenMsPreambleCount() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.preambleCount, 18)
    }

    
    // MARK: 14.5ms tests
    
    /// Test that when we use a pulseWidth of 14.5ms, the length of a one bit is 4 pulses (58ms).
    func testGoldilocksMsOneBit() {
        let timing = try! BitstreamTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.oneBitLength, 4)
    }
    
    /// Test that when we use a pulseWidth of 14.5ms, the length of a zero bit is 7 pulses (101.5ms).
    func testGoldilocksMsZeroBit() {
        let timing = try! BitstreamTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.zeroBitLength, 7)
    }
    
    /// Test that when we use a pulseWidth of 14.5ms, the length of the RailCom start delay is 2 pulses (29ms).
    func testGoldilocksMsRailComDelay() {
        let timing = try! BitstreamTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.railComDelayLength, 2)
    }
    
    /// Test that when we use a pulseWidth of 14.5ms, the length of a RailCom cutout is 32 pulses (464ms).
    func testGoldilocksMsRailCom() {
        let timing = try! BitstreamTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.railComLength, 32)
    }
    
    /// Test that when we use a pulseWidth of 14.5ms, RailCom requires 4 one bits.
    func testGoldilocksMsRailComCount() {
        let timing = try! BitstreamTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.railComCount, 4)
    }
    
    /// Test that when we use a pulseWidth of 14.5ms, a preamble requires 18 one bits.
    func testGoldilocksMsPreambleCount() {
        let timing = try! BitstreamTiming(pulseWidth: 14.5)
        XCTAssertEqual(timing.preambleCount, 18)
    }

    
    // MARK: failing tests
    
    /// Test that when we try and use a pulse width of 25ms, the initializer throws an error because
    /// this wouldn't produce an acceptable one bit duration.
    func testFailOneBit() {
        XCTAssertThrowsError(try BitstreamTiming(pulseWidth: 25))
    }
    
    /// Test that when we try and use a pulse width of 58ms, the initializer throws an error because
    /// this wouldn't produce an acceptable RailCom cutout delay.
    func testFailRailComDelay() {
        XCTAssertThrowsError(try BitstreamTiming(pulseWidth: 58))
    }

}
