//
//  BitstreamTests.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/27/16.
//
//

import XCTest

@testable import DCC


class BitstreamTests: XCTestCase {
    
    var wordSize: Int = 0
    
    override func setUp() {
        wordSize = MemoryLayout<Int>.size * 8
    }
    
    /// Test that a zero count input is accepted and doesn't add any output.
    func testPhysicalBitsZeroCount() {
        var x = Bitstream()
        x.append(physicalBits: 0, count: 0)
        
        XCTAssertEqual(x.count, 0)
    }

    /// Test that, for each possible count, the input right-aligned bits are left-aligned in the output.
    ///
    /// For this we use an input bit pattern of `i` 1s.
    func testPhysicalBitsAllOnes() {
        for i in 1...wordSize {
            let bits = i < wordSize ? ~(~0 << i) : ~0

            var x = Bitstream()
            x.append(physicalBits: bits, count: i)
        
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: bits << (wordSize - i), size: i))
        }
    }
    
    /// Test that, for each possible count, an input of zero bits ends up as zero bits in the output.
    func testPhysicalBitsAllZeros() {
        for i in 1...wordSize {
            var x = Bitstream()
            x.append(physicalBits: 0, count: i)
            
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: 0, size: i))
        }
    }
    
    /// Test that, for each possible count, an input beginning in a zero bit ends up correctly in the output.
    func testPhysicalBitsLeadingZero() {
        for i in 1...wordSize {
            let bits = ~(~0 << (i - 1))
            
            var x = Bitstream()
            x.append(physicalBits: bits, count: i)
            
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: bits << (wordSize - i), size: i))
        }
    }

    /// Test that, for each possible count, an input ending in a zero bit ends up correctly in the output.
    func testPhysicalBitsTrailingZero() {
        for i in 1...wordSize {
            let bits = ~(~0 << (i - 1)) << 1
            
            var x = Bitstream()
            x.append(physicalBits: bits, count: i)
            
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: bits << (wordSize - i), size: i))
        }
    }
    
    /// Test that a second append of physical bits extends the first rather than adding a second data.
    func testPhysicalBitsExtends() {
        var x = Bitstream()
        x.append(physicalBits: 0b1100, count: 4)

        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(physicalBits: 0b1010, count: 4)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b11001010 << (wordSize - 8), size: 8))
    }
    
    /// Test that a second append of physical bits extends the first, and adds another, when there isn't room for all of it.
    func testPhysicalBitsExtendsAndAppends() {
        let bits = ~(~0 << (wordSize - 4))
        
        var x = Bitstream()
        x.append(physicalBits: bits, count: wordSize - 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 4, size: wordSize - 4))
        
        x.append(physicalBits: 0b10101010, count: 8)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 4) | 0b1010, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b1010 << (wordSize - 4), size: 4))
    }
    
    /// Test that a second append of physical bits extends the first, and doesn't add another when it fits, unless a third is appended.
    func testPhysicalBitsExtendsPerfectly() {
        let bits = ~(~0 << (wordSize - 8))
        
        var x = Bitstream()
        x.append(physicalBits: bits, count: wordSize - 8)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 8, size: wordSize - 8))
        
        x.append(physicalBits: 0b10101010, count: 8)
        
        // Test for the perfect fit.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: (bits << 8) | 0b10101010, size: wordSize))

        // Third append.
        x.append(physicalBits: 0b1111, count: 4)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 8) | 0b10101010, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }
    
    /// Test that physical bits can go after non-data.
    func testPhysicalBitsAfterNonData() {
        var x = Bitstream()
        x.append(.debugStart)
        x.append(physicalBits: 0b1111, count: 4)

        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .debugStart)
        XCTAssertEqual(x[1], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }
    
    /// Test that physical bits don't try and extend a data prior to a non-data, even when non-complete.
    ///
    /// Sizes should remain short.
    func testPhysicalBitsSandwichNonData() {
        var x = Bitstream()
        x.append(physicalBits: 0b10101010, count: 8)
        x.append(.debugStart)
        x.append(physicalBits: 0b1111, count: 4)
        
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(x[0], .data(word: 0b10101010 << (wordSize - 8), size: 8))
        XCTAssertEqual(x[1], .debugStart)
        XCTAssertEqual(x[2], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }

}

extension BitstreamTests {
    
    static var allTests = {
        return [
            ("testPhysicalBitsZeroCount", testPhysicalBitsZeroCount),
            ("testPhysicalBitsAllOnes", testPhysicalBitsAllOnes),
            ("testPhysicalBitsAllZeros", testPhysicalBitsAllZeros),
            ("testPhysicalBitsLeadingZero", testPhysicalBitsLeadingZero),
            ("testPhysicalBitsTrailingZero", testPhysicalBitsTrailingZero),
            ("testPhysicalBitsExtends", testPhysicalBitsExtends),
            ("testPhysicalBitsExtendsAndAppends", testPhysicalBitsExtendsAndAppends),
            ("testPhysicalBitsExtendsPerfectly", testPhysicalBitsExtendsPerfectly),
            ("testPhysicalBitsAfterNonData", testPhysicalBitsAfterNonData),
            ("testPhysicalBitsSandwichNonData", testPhysicalBitsSandwichNonData),
            ]
    }()

}
