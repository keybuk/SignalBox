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
    func testMicrosecondRailComCutout() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComCutoutLength, 454)
    }

    /// Test that when we use a pulseWidth of 1ms, the total RailCom length is 464 pulses, which
    /// is derived from the number of one bits required for it.
    func testMicrosecondRailCom() {
        let timing = try! BitstreamTiming(pulseWidth: 1)
        XCTAssertEqual(timing.railComLength, 464)
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
    func testTenMsRailComCutout() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComCutoutLength, 46)
    }
    
    /// Test that when we use a pulseWidth of 10ms, the total RailCom length is 48 pulses (480ms), which
    /// is derived from the number of one bits required for it.
    func testTenMsRailCom() {
        let timing = try! BitstreamTiming(pulseWidth: 10)
        XCTAssertEqual(timing.railComLength, 48)
    }

    
    // MARK: failing tests
    
    /// Test that when we try and use a pulse width of 25ms, the initializer throws an error because
    /// this wouldn't produce an acceptable one bit duration.
    func testFailOneBit() {
        XCTAssertThrowsError(try BitstreamTiming(pulseWidth: 25))
    }
    
}
