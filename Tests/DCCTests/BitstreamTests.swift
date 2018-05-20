//
//  BitstreamTests.swift
//  DCCTests
//
//  Created by Scott James Remnant on 5/19/18.
//

import XCTest

import DCC

// Since the word size is platform specific, we don't want to test where the word boundaries lie.
// Easiest solution is to concatenate the string values of all of the words, and chop off the last
// part that isn't used yet.
extension Bitstream {
    
    var stringValue: String {
        let stringValue = words.map({ $0.binaryString }).joined()
        let endIndex = stringValue.index(stringValue.endIndex, offsetBy: -bitsRemaining)
        return String(stringValue[..<endIndex])
    }
    
}

class BitstreamTests: XCTestCase {

    /// Goldilocks value for pulse width that gives a small number of output bits while
    /// maintaining timing accuracy.
    let pulseWidth: Float = 14.5
    
    // MARK: add(:length)

    /// Test that we can add a one bit to an empty bitstream.
    func testOneBit() {
        let timing = try! BitstreamTiming(pulseWidth: pulseWidth)
        var bitstream = Bitstream(timing: timing)
        bitstream.add(0b1, length: 1)
        
        XCTAssertEqual(bitstream.stringValue, "11110000")
    }
    
    /// Test that we can add a zero bit to an empty bitstream.
    func testZeroBit() {
        let timing = try! BitstreamTiming(pulseWidth: pulseWidth)
        var bitstream = Bitstream(timing: timing)
        bitstream.add(0b0, length: 1)
        
        XCTAssertEqual(bitstream.stringValue, "11111110000000")
    }

    /// Test that we can add multiple bits to a stream in one call.
    func testMultipleBits() {
        let timing = try! BitstreamTiming(pulseWidth: pulseWidth)
        var bitstream = Bitstream(timing: timing)
        bitstream.add(0b10, length: 2)
        
        XCTAssertEqual(bitstream.stringValue,
                       ["11110000", "11111110000000"].joined())
    }

    /// Test that we can add bits by consecutive calls.
    func testConsecutiveBits() {
        let timing = try! BitstreamTiming(pulseWidth: pulseWidth)
        var bitstream = Bitstream(timing: timing)
        bitstream.add(0b0, length: 1)
        bitstream.add(0b1, length: 1)

        XCTAssertEqual(bitstream.stringValue,
                       ["11111110000000", "11110000"].joined())
    }
    
    /// Test that we can add a full byte value, filling multiple words.
    func testMultipleWords() {
        let timing = try! BitstreamTiming(pulseWidth: pulseWidth)
        var bitstream = Bitstream(timing: timing)
        bitstream.add(0b10101100, length: 8)

        XCTAssertEqual(bitstream.stringValue,
                       ["11110000", "11111110000000", "11110000", "11111110000000",
                        "11110000", "11110000", "11111110000000", "11111110000000"].joined())

    }
    
    // MARK: duration
    
    /// Test that the duration of a bitstream can be calculated.
    func testDuration() {
        let timing = try! BitstreamTiming(pulseWidth: pulseWidth)
        var bitstream = Bitstream(timing: timing)
        bitstream.add(0b10101100, length: 8)
        
        // 1,276ms = 88 bits × 14.5ms per bit.
        XCTAssertEqual(bitstream.duration, 1276)
    }
    
    /// Test that the duration of an empty bitstream is zero.
    func testEmptyDuration() {
        let timing = try! BitstreamTiming(pulseWidth: pulseWidth)
        let bitstream = Bitstream(timing: timing)
        
        XCTAssertEqual(bitstream.duration, 0)
    }

}
