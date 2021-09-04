//
//  SignalPackerTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/19/18.
//

import XCTest

import DCC

class SignalPackerTests : XCTestCase {

    /// Goldilocks value for pulse width that gives a small number of output bits while
    /// maintaining timing accuracy.
    let pulseWidth: Float = 14.5
    
    // MARK: add(:length)

    /// Test that we can add a one bit to an empty packer.
    func testOneBit() {
        let timing = try! SignalTiming(pulseWidth: pulseWidth)
        var packer = SignalPacker(timing: timing)
        packer.add(0b1, length: 1)
        
        XCTAssertEqual(packer.packedValues, [0b11110000 << packer.bitsRemaining])
    }
    
    /// Test that we can add a zero bit to an empty packer.
    func testZeroBit() {
        let timing = try! SignalTiming(pulseWidth: pulseWidth)
        var packer = SignalPacker(timing: timing)
        packer.add(0b0, length: 1)
        
        XCTAssertEqual(packer.packedValues, [0b111111_10000000 << packer.bitsRemaining])
    }

    /// Test that we can add multiple bits to a packer in one call.
    func testMultipleBits() {
        let timing = try! SignalTiming(pulseWidth: pulseWidth)
        var packer = SignalPacker(timing: timing)
        packer.add(0b10, length: 2)
        
        XCTAssertEqual(packer.packedValues, [0b111100_00111111_10000000 << packer.bitsRemaining])
    }

    /// Test that we can add bits by consecutive calls.
    func testConsecutiveBits() {
        let timing = try! SignalTiming(pulseWidth: pulseWidth)
        var packer = SignalPacker(timing: timing)
        packer.add(0b0, length: 1)
        packer.add(0b1, length: 1)

        XCTAssertEqual(packer.packedValues, [0b111111_10000000_11110000 << packer.bitsRemaining])
    }
    
    /// Test that we can add a full byte value, filling multiple words.
    func testMultipleWords() {
        let timing = try! SignalTiming(pulseWidth: pulseWidth)
        var packer = SignalPacker(timing: timing)
        packer.add(0b10101100, length: 8)

        XCTAssertEqual(packer.packedValues, [0b11110000_11111110_00000011_11000011, 0b11111000_00001111_00001111_00001111, 0b11100000_00111111_10000000 << packer.bitsRemaining])

    }
    
    // MARK: duration
    
    /// Test that the duration of a packer can be calculated.
    func testDuration() {
        let timing = try! SignalTiming(pulseWidth: pulseWidth)
        var packer = SignalPacker(timing: timing)
        packer.add(0b10101100, length: 8)
        
        // 1,276ms = 88 bits × 14.5ms per bit.
        XCTAssertEqual(packer.duration, 1276)
    }
    
    /// Test that the duration of an empty packer is zero.
    func testEmptyDuration() {
        let timing = try! SignalTiming(pulseWidth: pulseWidth)
        let packer = SignalPacker(timing: timing)
        
        XCTAssertEqual(packer.duration, 0)
    }

}
