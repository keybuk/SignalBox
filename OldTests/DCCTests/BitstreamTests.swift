//
//  BitstreamTests.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/27/16.
//
//

import XCTest

@testable import OldDCC


class BitstreamTests : XCTestCase {
    
    var wordSize: Int = 0
    
    override func setUp() {
        super.setUp()
        wordSize = MemoryLayout<Int>.size * 8
    }
    
    /// Test that we get the collection members for free.
    func testCollection() {
        var x = Bitstream(bitDuration: 14.5)
        
        XCTAssertEqual(x.count, 0)
        XCTAssertTrue(x.isEmpty)
        
        x.append(.debugStart)

        XCTAssertFalse(x.isEmpty)
    }
    
    
    // MARK: Events
    
    /// Test that we can append an event.
    func testEvent() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(.debugStart)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .debugStart)
    }
    
    /// Test that we can append multiple events.
    func testEventMultiple() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(.debugStart)
        x.append(.debugEnd)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .debugStart)
        XCTAssertEqual(x[1], .debugEnd)
    }

    
    // MARK: Physical Bits

    /// Test that a zero count input is accepted and doesn't add any output.
    func testPhysicalBitsZeroCount() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0, count: 0)
        
        XCTAssertEqual(x.count, 0)
    }

    /// Test that, for each possible count, the input right-aligned bits are left-aligned in the output.
    ///
    /// For this we use an input bit pattern of `i` 1s.
    func testPhysicalBitsAllOnes() {
        for i in 1...wordSize {
            let bits = i < wordSize ? ~(~0 << i) : ~0

            var x = Bitstream(bitDuration: 14.5)
            x.append(physicalBits: bits, count: i)
        
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: bits << (wordSize - i), size: i))
        }
    }
    
    /// Test that, for each possible count, an input of zero bits ends up as zero bits in the output.
    func testPhysicalBitsAllZeros() {
        for i in 1...wordSize {
            var x = Bitstream(bitDuration: 14.5)
            x.append(physicalBits: 0, count: i)
            
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: 0, size: i))
        }
    }
    
    /// Test that, for each possible count, an input beginning in a zero bit ends up correctly in the output.
    func testPhysicalBitsLeadingZero() {
        for i in 1...wordSize {
            let bits = ~(~0 << (i - 1))
            
            var x = Bitstream(bitDuration: 14.5)
            x.append(physicalBits: bits, count: i)
            
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: bits << (wordSize - i), size: i))
        }
    }

    /// Test that, for each possible count, an input ending in a zero bit ends up correctly in the output.
    func testPhysicalBitsTrailingZero() {
        for i in 1...wordSize {
            let bits = ~(~0 << (i - 1)) << 1
            
            var x = Bitstream(bitDuration: 14.5)
            x.append(physicalBits: bits, count: i)
            
            XCTAssertEqual(x.count, 1)
            XCTAssertEqual(x[0], .data(word: bits << (wordSize - i), size: i))
        }
    }
    
    /// Test that a second append of physical bits extends the first rather than adding a second data.
    func testPhysicalBitsExtends() {
        var x = Bitstream(bitDuration: 14.5)
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
        
        var x = Bitstream(bitDuration: 14.5)
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
        
        var x = Bitstream(bitDuration: 14.5)
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
    
    /// Test that a second append of physical bits with a zero count doesn't change the first.
    func testPhysicalBitsExtendsZeroCount() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b1100, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(physicalBits: 0, count: 0)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
    }
    
    /// Test that physical bits can go after non-data.
    func testPhysicalBitsAfterNonData() {
        var x = Bitstream(bitDuration: 14.5)
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
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b10101010, count: 8)
        x.append(.debugStart)
        x.append(physicalBits: 0b1111, count: 4)
        
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(x[0], .data(word: 0b10101010 << (wordSize - 8), size: 8))
        XCTAssertEqual(x[1], .debugStart)
        XCTAssertEqual(x[2], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }
    
    
    // MARK: Repeating Physical Bits
    
    /// Test that a zero count input is accepted and doesn't add any output.
    func testRepeatingPhysicalOneBitZeroCount() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 0)
        
        XCTAssertEqual(x.count, 0)
    }
    
    /// Test that physical bits with a positive count append data.
    func testRepeatingPhysicalOneBit() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 8)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b11111111 << (wordSize - 8), size: 8))
    }

    /// Test that physical bits with a count greater than a short word size result in multiple data.
    ///
    /// Since the wordSize initializer is only available for tests, this is a test to make sure functionality we rely on in other tests, works.
    func testRepeatingPhysicalOneBitShortWordSize() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 6)
        x.append(repeatingPhysicalBit: 1, count: 8)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: 0b111111, size: 6))
        XCTAssertEqual(x[1], .data(word: 0b11 << 4, size: 2))
    }

    /// Test that physical bits with a count greater than the natural word size result in multiple data.
    func testRepeatingPhysicalOneBitLongerThanWord() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: wordSize + 8)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: ~0, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b11111111 << (wordSize - 8), size: 8))
    }

    /// Test that a second append of physical bits extends the first rather than adding a second data.
    func testRepeatingPhysicalOneBitExtends() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b1100, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(repeatingPhysicalBit: 1, count: 4)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b11001111 << (wordSize - 8), size: 8))
    }
    
    /// Test that a second append of physical bits extends the first, and adds another, when there isn't room for all of it.
    func testRepeatingPhysicalOneBitExtendsAndAppends() {
        let bits = ~(~0 << (wordSize - 4))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 4, size: wordSize - 4))
        
        x.append(repeatingPhysicalBit: 1, count: 8)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 4) | 0b1111, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }
    
    /// Test that a second append of physical bits extends the first, and doesn't add another when it fits, unless a third is appended.
    func testRepeatingPhysicalOneBitExtendsPerfectly() {
        let bits = ~(~0 << (wordSize - 8))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 8)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 8, size: wordSize - 8))
        
        x.append(repeatingPhysicalBit: 1, count: 8)
        
        // Test for the perfect fit.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: (bits << 8) | 0b11111111, size: wordSize))
        
        // Third append.
        x.append(repeatingPhysicalBit: 1, count: 4)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 8) | 0b11111111, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }
    
    /// Test that a second append of physical bits with a zero count does not modify the first.
    func testRepeatingPhysicalOneBitExtendsZeroCount() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b1100, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(repeatingPhysicalBit: 1, count: 0)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
    }

    /// Test that physical bits can go after non-data.
    func testRepeatingPhysicalOneBitAfterNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(.debugStart)
        x.append(repeatingPhysicalBit: 1, count: 4)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .debugStart)
        XCTAssertEqual(x[1], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }
    
    /// Test that physical bits don't try and extend a data prior to a non-data, even when non-complete.
    ///
    /// Sizes should remain short.
    func testRepeatingPhysicalOneBitSandwichNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b10101010, count: 8)
        x.append(.debugStart)
        x.append(repeatingPhysicalBit: 1, count: 4)
        
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(x[0], .data(word: 0b10101010 << (wordSize - 8), size: 8))
        XCTAssertEqual(x[1], .debugStart)
        XCTAssertEqual(x[2], .data(word: 0b1111 << (wordSize - 4), size: 4))
    }

    /// Test that a zero count input is accepted and doesn't add any output.
    func testRepeatingPhysicalZeroBitZeroCount() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 0, count: 0)
        
        XCTAssertEqual(x.count, 0)
    }

    /// Test that physical bits with a positive count append data.
    func testRepeatingPhysicalZeroBit() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 0, count: 8)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0, size: 8))
    }
    
    /// Test that physical bits with a count greater than a short word size result in multiple data.
    ///
    /// Since the wordSize initializer is only available for tests, this is a test to make sure functionality we rely on in other tests, works.
    func testRepeatingPhysicalZeroBitShortWordSize() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 6)
        x.append(repeatingPhysicalBit: 0, count: 8)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: 0, size: 6))
        XCTAssertEqual(x[1], .data(word: 0, size: 2))
    }
    
    /// Test that physical bits with a count greater than the natural word size result in multiple data.
    func testRepeatingPhysicalZeroBitLongerThanWord() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 0, count: wordSize + 8)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: 0, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0, size: 8))
    }
    
    /// Test that a second append of physical bits extends the first rather than adding a second data.
    func testRepeatingPhysicalZeroBitExtends() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b1100, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(repeatingPhysicalBit: 0, count: 4)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 8))
    }
    
    /// Test that a second append of physical bits extends the first, and adds another, when there isn't room for all of it.
    func testRepeatingPhysicalZeroBitExtendsAndAppends() {
        let bits = ~(~0 << (wordSize - 4))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 4, size: wordSize - 4))
        
        x.append(repeatingPhysicalBit: 0, count: 8)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: bits << 4, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0, size: 4))
    }
    
    /// Test that a second append of physical bits extends the first, and doesn't add another when it fits, unless a third is appended.
    func testRepeatingPhysicalZeroBitExtendsPerfectly() {
        let bits = ~(~0 << (wordSize - 8))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 8)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 8, size: wordSize - 8))
        
        x.append(repeatingPhysicalBit: 0, count: 8)
        
        // Test for the perfect fit.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 8, size: wordSize))
        
        // Third append.
        x.append(repeatingPhysicalBit: 0, count: 4)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: bits << 8, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0, size: 4))
    }
    
    /// Test that a second append of physical bits with a zero count does not modify the first.
    func testRepeatingPhysicalZeroBitExtendsZeroCount() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b1100, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(repeatingPhysicalBit: 0, count: 0)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
    }

    /// Test that physical bits can go after non-data.
    func testRepeatingPhysicalZeroBitAfterNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(.debugStart)
        x.append(repeatingPhysicalBit: 0, count: 4)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .debugStart)
        XCTAssertEqual(x[1], .data(word: 0, size: 4))
    }
    
    /// Test that physical bits don't try and extend a data prior to a non-data, even when non-complete.
    ///
    /// Sizes should remain short.
    func testRepeatingPhysicalZeroBitSandwichNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b10101010, count: 8)
        x.append(.debugStart)
        x.append(repeatingPhysicalBit: 0, count: 4)
        
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(x[0], .data(word: 0b10101010 << (wordSize - 8), size: 8))
        XCTAssertEqual(x[1], .debugStart)
        XCTAssertEqual(x[2], .data(word: 0, size: 4))
    }

    /// Test that a physical zero bits can be appended to physical one bits.
    func testRepeatingPhysicalZeroBitAfterOne() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1111 << (wordSize - 4), size: 4))
        
        x.append(repeatingPhysicalBit: 0, count: 4)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1111 << (wordSize - 4), size: 8))
    }

    /// Test that a physical one bits can be appended to physical zero bits.
    func testRepeatingPhysicalOneBitAfterZero() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 0, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0, size: 4))
        
        x.append(repeatingPhysicalBit: 1, count: 4)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1111 << (wordSize - 8), size: 8))
    }

    
    // MARK: Logical Bits
    
    /// Test that a logical one bit is appended as the right number and values of physical bits.
    func testLogicalOneBit() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b11110000 << (wordSize - 8), size: 8))
    }

    /// Test that a logical one bit can be broken up into multiple data if it doesn't fit.
    func testLogicalOneBitDoesntFit() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 3)
        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(x[0], .data(word: 0b111, size: 3))
        XCTAssertEqual(x[1], .data(word: 0b100, size: 3))
        XCTAssertEqual(x[2], .data(word: 0b00 << 1, size: 2))
    }
    
    /// Test that a logical one bit can extend existing data.
    func testLogicalOneBitExtends() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b1100, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b110011110000 << (wordSize - 12), size: 12))
    }
    
    /// Test that a logical one bit can extend existing data, and the remainder appended, where it doesn't fit.
    func testLogicalOneBitExtendsAndAppends() {
        let bits = ~(~0 << (wordSize - 4))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 4, size: wordSize - 4))

        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 4) | 0b1111, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b0000 << (wordSize - 4), size: 4))
    }

    /// Test that a logical one bit can extend existing data, and doesn't add another when it fits, unless another is appended.
    func testLogicalOneBitExtendsPerfectly() {
        let bits = ~(~0 << (wordSize - 8))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 8)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 8, size: wordSize - 8))
        
        x.append(logicalBit: 1)
        
        // Test for the perfect fit.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: (bits << 8) | 0b11110000, size: wordSize))
        
        // Extra append.
        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 8) | 0b11110000, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b11110000 << (wordSize - 8), size: 8))
    }

    /// Test that a logical one bit can go after non-data.
    func testLogicalOneBitAfterNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(.debugStart)
        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .debugStart)
        XCTAssertEqual(x[1], .data(word: 0b11110000 << (wordSize - 8), size: 8))
    }
    
    /// Test that appending a logical one bit doesn't try and extend a data prior to a non-data, even when non-complete.
    ///
    /// Sizes should remain short.
    func testLogicalOneBitSandwichNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b10101010, count: 8)
        x.append(.debugStart)
        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(x[0], .data(word: 0b10101010 << (wordSize - 8), size: 8))
        XCTAssertEqual(x[1], .debugStart)
        XCTAssertEqual(x[2], .data(word: 0b11110000 << (wordSize - 8), size: 8))
    }

    /// Test that a logical one bit is appended as the right number and values of physical bits even with an unusual length.
    func testLogicalOneBitAlternateLength() {
        var x = Bitstream(bitDuration: 10)
        x.append(logicalBit: 1)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b111111000000 << (wordSize - 12), size: 12))
    }

    /// Test that a logical zero bit is appended as the right number and values of physical bits.
    func testLogicalZeroBit() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b11111110000000 << (wordSize - 14), size: 14))
    }
    
    /// Test that a logical zero bit can be broken up into multiple data if it doesn't fit.
    func testLogicalZeroBitDoesntFit() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 3)
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 5)
        XCTAssertEqual(x[0], .data(word: 0b111, size: 3))
        XCTAssertEqual(x[1], .data(word: 0b111, size: 3))
        XCTAssertEqual(x[2], .data(word: 0b100, size: 3))
        XCTAssertEqual(x[3], .data(word: 0b000, size: 3))
        XCTAssertEqual(x[4], .data(word: 0b00 << 1, size: 2))
    }
    
    /// Test that a logical zero bit can extend existing data.
    func testLogicalZeroBitExtends() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b1100, count: 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b1100 << (wordSize - 4), size: 4))
        
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b110011111110000000 << (wordSize - 18), size: 18))
    }
    
    /// Test that a logical zero bit can extend existing data, and the remainder appended, where it doesn't fit.
    func testLogicalZeroBitExtendsAndAppends() {
        let bits = ~(~0 << (wordSize - 4))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 4)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 4, size: wordSize - 4))
        
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 4) | 0b1111, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b1110000000 << (wordSize - 10), size: 10))
    }
    
    /// Test that a logical zero bit can extend existing data, and doesn't add another when it fits, unless another is appended.
    func testLogicalZeroBitExtendsPerfectly() {
        let bits = ~(~0 << (wordSize - 14))
        
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: bits, count: wordSize - 14)
        
        // Sanity check.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: bits << 14, size: wordSize - 14))
        
        x.append(logicalBit: 0)
        
        // Test for the perfect fit.
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: (bits << 14) | 0b11111110000000, size: wordSize))
        
        // Extra append.
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .data(word: (bits << 14) | 0b11111110000000, size: wordSize))
        XCTAssertEqual(x[1], .data(word: 0b11111110000000 << (wordSize - 14), size: 14))
    }

    /// Test that a logical zero bit can go after non-data.
    func testLogicalZeroBitAfterNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(.debugStart)
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 2)
        XCTAssertEqual(x[0], .debugStart)
        XCTAssertEqual(x[1], .data(word: 0b111111110000000 << (wordSize - 14), size: 14))
    }
    
    /// Test that appending a logical zero bit doesn't try and extend a data prior to a non-data, even when non-complete.
    ///
    /// Sizes should remain short.
    func testLogicalZeroBitSandwichNonData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(physicalBits: 0b10101010, count: 8)
        x.append(.debugStart)
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(x[0], .data(word: 0b10101010 << (wordSize - 8), size: 8))
        XCTAssertEqual(x[1], .debugStart)
        XCTAssertEqual(x[2], .data(word: 0b111111110000000 << (wordSize - 14), size: 14))
    }

    /// Test that a logical zero bit is appended as the right number and values of physical bits even with an unusual length.
    func testLogicalZeroBitAlternateLength() {
        var x = Bitstream(bitDuration: 10)
        x.append(logicalBit: 0)
        
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], .data(word: 0b11111111110000000000 << (wordSize - 20), size: 20))
    }

    
    // MARK: Preamble
    
    /// Test that we can append a preamble of default length.
    ///
    /// This should append the data for fourteen logical one bits.
    func testPreamble() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.appendPreamble()
        
        XCTAssertEqual(x.count, 4)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[1], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b1111000011110000) << 16, size: 16))
    }
    
    /// Test that we can append a long preamble with a specified length.
    func testPreambleWithLength() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.appendPreamble(length: 20)
        
        XCTAssertEqual(x.count, 5)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[1], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[4], .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
    }
    
    /// Test that appending a preamble extends any existing data.
    func testPreambleExtends() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.append(physicalBits: 0b101010, count: 6)
        x.appendPreamble()
        
        XCTAssertEqual(x.count, 4)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b10101011110000111100001111000011), size: 32))
        XCTAssertEqual(x[1], .data(word: Int(bitPattern: 0b11000011110000111100001111000011), size: 32))
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b11000011110000111100001111000011), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b1100001111000011110000) << 10, size: 22))
    }
    
    /// Test that a preamble can be generated using an unusual bit length.
    func testPreambleAlternateLength() {
        var x = Bitstream(bitDuration: 10, wordSize: 32)
        x.appendPreamble()
        
        XCTAssertEqual(x.count, 6)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[1], .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b11000000111111000000111111000000), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[4], .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[5], .data(word: Int(bitPattern: 0b11000000) << 24, size: 8))
    }

    
    // MARK: RailCom Cutout
    
    /// Test that we can append a RailCom cutout.
    ///
    /// This is a relatively complicated structure consisting of a 26µs delay, before the start event, and a total length of 454µs before the end event. The events cut into an ordinary transmission of logical one bits which should be complete in form.
    func testRailComCutout() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.appendRailComCutout()
        
        XCTAssertEqual(x.count, 4)
        XCTAssertEqual(x[0], .data(word: 0b11 << 30, size: 2))
        XCTAssertEqual(x[1], .railComCutoutStart)
        XCTAssertEqual(x[2], .data(word: 0b110000111100001111000011110000 << 2, size: 30))
        XCTAssertEqual(x[3], .railComCutoutEnd)
    }
    
    /// Test that appending a RailCom cutout extends any existing data.
    func testRailComCutoutExtends() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.append(physicalBits: 0b101010, count: 6)
        x.appendRailComCutout()
        
        XCTAssertEqual(x.count, 4)
        XCTAssertEqual(x[0], .data(word: 0b10101011 << 24, size: 8))
        XCTAssertEqual(x[1], .railComCutoutStart)
        XCTAssertEqual(x[2], .data(word: 0b110000111100001111000011110000 << 2, size: 30))
        XCTAssertEqual(x[3], .railComCutoutEnd)
    }
    
    /// Test that we can include the debug marker with the end of the RailCom cutout.
    func testRailComCutoutWithDebug() {
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.appendRailComCutout(debug: true)
        
        XCTAssertEqual(x.count, 5)
        XCTAssertEqual(x[0], .data(word: 0b11 << 30, size: 2))
        XCTAssertEqual(x[1], .railComCutoutStart)
        XCTAssertEqual(x[2], .data(word: 0b110000111100001111000011110000 << 2, size: 30))
        XCTAssertEqual(x[3], .railComCutoutEnd)
        XCTAssertEqual(x[4], .debugEnd)
    }
    
    /// Test that a RailCom cutout can be included when using an unusual length that alters the marker locations and requires a trailing part.
    func testRailComCutoutAlternateLength() {
        var x = Bitstream(bitDuration: 10.0, wordSize: 32)
        x.appendRailComCutout()
        
        XCTAssertEqual(x.count, 6)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b111) << 29, size: 3))
        XCTAssertEqual(x[1], .railComCutoutStart)
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b11100000011111100000011111100000), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b01111110000) << 21, size: 11))
        XCTAssertEqual(x[4], .railComCutoutEnd)
        XCTAssertEqual(x[5], .data(word: Int(bitPattern: 0b00) << 30, size: 2))
    }
    
    /// Test that a RailCom cutout, when using an unusual length, places the debug marker along with the cutout end.
    func testRailComCutoutAlternateLengthWithDebug() {
        var x = Bitstream(bitDuration: 10.0, wordSize: 32)
        x.appendRailComCutout(debug: true)
        
        XCTAssertEqual(x.count, 7)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b111) << 29, size: 3))
        XCTAssertEqual(x[1], .railComCutoutStart)
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b11100000011111100000011111100000), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b01111110000) << 21, size: 11))
        XCTAssertEqual(x[4], .railComCutoutEnd)
        XCTAssertEqual(x[5], .debugEnd)
        XCTAssertEqual(x[6], .data(word: Int(bitPattern: 0b00) << 30, size: 2))
    }

    
    // MARK: Packet
    
    /// Test that we can append a DCC packet.
    ///
    /// Since the packet is already serialized in byte form, what we're checking here is that the logical bits of those bytes are turned into physical bits, that they are separated by zero bits, prefixed by a zero packet start bit, and terminated by a one packet end bit.
    func testPacket() {
        let packet: Packet = .speed28Step(address: 3, direction: .forward, speed: 14) //(bytes: [0b00000011, 0b01111000, 0b01111011])

        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.append(packet: packet)

        XCTAssertEqual(x.count, 10)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b11111110000000111111100000001111), size: 32))
        XCTAssertEqual(x[1], .data(word: Int(bitPattern: 0b11100000001111111000000011111110), size: 32))
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b00000011111110000000111111100000), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b00111100001111000011111110000000), size: 32))
        XCTAssertEqual(x[4], .data(word: Int(bitPattern: 0b11111110000000111100001111000011), size: 32))
        XCTAssertEqual(x[5], .data(word: Int(bitPattern: 0b11000011110000111111100000001111), size: 32))
        XCTAssertEqual(x[6], .data(word: Int(bitPattern: 0b11100000001111111000000011111110), size: 32))
        XCTAssertEqual(x[7], .data(word: Int(bitPattern: 0b00000011111110000000111100001111), size: 32))
        XCTAssertEqual(x[8], .data(word: Int(bitPattern: 0b00001111000011110000111111100000), size: 32))
        XCTAssertEqual(x[9], .data(word: Int(bitPattern: 0b00111100001111000011110000) << 6, size: 26))
    }

    /// Test that appending a packet extends any existing data.
    func testPacketExtends() {
        let packet: Packet = .speed28Step(address: 3, direction: .forward, speed: 14) //(bytes: [0b00000011, 0b01111000, 0b01111011])
        
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.append(physicalBits: 0b101010, count: 6)
        x.append(packet: packet)
        
        XCTAssertEqual(x.count, 10)
        XCTAssertEqual(x[0], .data(word: Int(bitPattern: 0b10101011111110000000111111100000), size: 32))
        XCTAssertEqual(x[1], .data(word: Int(bitPattern: 0b00111111100000001111111000000011), size: 32))
        XCTAssertEqual(x[2], .data(word: Int(bitPattern: 0b11111000000011111110000000111111), size: 32))
        XCTAssertEqual(x[3], .data(word: Int(bitPattern: 0b10000000111100001111000011111110), size: 32))
        XCTAssertEqual(x[4], .data(word: Int(bitPattern: 0b00000011111110000000111100001111), size: 32))
        XCTAssertEqual(x[5], .data(word: Int(bitPattern: 0b00001111000011110000111111100000), size: 32))
        XCTAssertEqual(x[6], .data(word: Int(bitPattern: 0b00111111100000001111111000000011), size: 32))
        XCTAssertEqual(x[7], .data(word: Int(bitPattern: 0b11111000000011111110000000111100), size: 32))
        XCTAssertEqual(x[8], .data(word: Int(bitPattern: 0b00111100001111000011110000111111), size: 32))
        XCTAssertEqual(x[9], .data(word: Int(bitPattern: 0b10000000111100001111000011110000), size: 32))
    }
    
    /// Test that appending a packet when using an unusual length appends the correct data.
    func testPacketAlternateLength() {
        let packet: Packet = .speed28Step(address: 3, direction: .forward, speed: 14) //(bytes: [0b00000011, 0b01111000, 0b01111011])
        
        var x = Bitstream(bitDuration: 10, wordSize: 32)
        x.append(packet: packet)
        
        XCTAssertEqual(x.count, 15)
        XCTAssertEqual(x[0],  .data(word: Int(bitPattern: 0b11111111110000000000111111111100), size: 32))
        XCTAssertEqual(x[1],  .data(word: Int(bitPattern: 0b00000000111111111100000000001111), size: 32))
        XCTAssertEqual(x[2],  .data(word: Int(bitPattern: 0b11111100000000001111111111000000), size: 32))
        XCTAssertEqual(x[3],  .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[4],  .data(word: Int(bitPattern: 0b11000000000011111100000011111100), size: 32))
        XCTAssertEqual(x[5],  .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[6],  .data(word: Int(bitPattern: 0b11000000000011111100000011111100), size: 32))
        XCTAssertEqual(x[7],  .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[8],  .data(word: Int(bitPattern: 0b11111100000000001111111111000000), size: 32))
        XCTAssertEqual(x[9],  .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[10], .data(word: Int(bitPattern: 0b11000000000011111111110000000000), size: 32))
        XCTAssertEqual(x[11], .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[12], .data(word: Int(bitPattern: 0b00001111110000001111111111000000), size: 32))
        XCTAssertEqual(x[13], .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[14], .data(word: Int(bitPattern: 0b11000000) << 24, size: 8))
    }

    
    
    // MARK: Operations Mode Packet
    
    /// Test that we can append a DCC packet for operations mode.
    ///
    /// This extends the append(packet:) method by prefixing with a preamble, and postfixing with a RailCom cutout.
    func testOperationsModePacket() {
        let packet: Packet = .speed28Step(address: 3, direction: .forward, speed: 14) //(bytes: [0b00000011, 0b01111000, 0b01111011])
        
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.append(operationsModePacket: packet)
        
        XCTAssertEqual(x.count, 17)
        XCTAssertEqual(x[0],  .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[1],  .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[2],  .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[3],  .data(word: Int(bitPattern: 0b11110000111100001111111000000011), size: 32))
        XCTAssertEqual(x[4],  .data(word: Int(bitPattern: 0b11111000000011111110000000111111), size: 32))
        XCTAssertEqual(x[5],  .data(word: Int(bitPattern: 0b10000000111111100000001111111000), size: 32))
        XCTAssertEqual(x[6],  .data(word: Int(bitPattern: 0b00001111111000000011110000111100), size: 32))
        XCTAssertEqual(x[7],  .data(word: Int(bitPattern: 0b00111111100000001111111000000011), size: 32))
        XCTAssertEqual(x[8],  .data(word: Int(bitPattern: 0b11000011110000111100001111000011), size: 32))
        XCTAssertEqual(x[9],  .data(word: Int(bitPattern: 0b11111000000011111110000000111111), size: 32))
        XCTAssertEqual(x[10], .data(word: Int(bitPattern: 0b10000000111111100000001111111000), size: 32))
        XCTAssertEqual(x[11], .data(word: Int(bitPattern: 0b00001111000011110000111100001111), size: 32))
        XCTAssertEqual(x[12], .data(word: Int(bitPattern: 0b00001111111000000011110000111100), size: 32))
        XCTAssertEqual(x[13], .data(word: Int(bitPattern: 0b001111000011) << 20, size: 12))
        XCTAssertEqual(x[14], .railComCutoutStart)
        XCTAssertEqual(x[15], .data(word: Int(bitPattern: 0b110000111100001111000011110000) << 2, size: 30))
        XCTAssertEqual(x[16], .railComCutoutEnd)
    }

    /// Test that we can append a DCC packet for operations mode, and mark it for debugging.
    ///
    /// This introduces `.debugStart`/`.debugEnd' events around the packet/RailCom cutout.
    func testOperationsModePacketWithDebug() {
        let packet: Packet = .speed28Step(address: 3, direction: .forward, speed: 14) //(bytes: [0b00000011, 0b01111000, 0b01111011])
        
        var x = Bitstream(bitDuration: 14.5, wordSize: 32)
        x.append(operationsModePacket: packet, debug: true)
        
        XCTAssertEqual(x.count, 19)
        XCTAssertEqual(x[0],  .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[1],  .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[2],  .data(word: Int(bitPattern: 0b11110000111100001111000011110000), size: 32))
        XCTAssertEqual(x[3],  .data(word: Int(bitPattern: 0b1111000011110000) << 16, size: 16))
        XCTAssertEqual(x[4],  .debugStart)
        XCTAssertEqual(x[5],  .data(word: Int(bitPattern: 0b11111110000000111111100000001111), size: 32))
        XCTAssertEqual(x[6],  .data(word: Int(bitPattern: 0b11100000001111111000000011111110), size: 32))
        XCTAssertEqual(x[7],  .data(word: Int(bitPattern: 0b00000011111110000000111111100000), size: 32))
        XCTAssertEqual(x[8],  .data(word: Int(bitPattern: 0b00111100001111000011111110000000), size: 32))
        XCTAssertEqual(x[9],  .data(word: Int(bitPattern: 0b11111110000000111100001111000011), size: 32))
        XCTAssertEqual(x[10], .data(word: Int(bitPattern: 0b11000011110000111111100000001111), size: 32))
        XCTAssertEqual(x[11], .data(word: Int(bitPattern: 0b11100000001111111000000011111110), size: 32))
        XCTAssertEqual(x[12], .data(word: Int(bitPattern: 0b00000011111110000000111100001111), size: 32))
        XCTAssertEqual(x[13], .data(word: Int(bitPattern: 0b00001111000011110000111111100000), size: 32))
        XCTAssertEqual(x[14], .data(word: Int(bitPattern: 0b0011110000111100001111000011) << 4, size: 28))
        XCTAssertEqual(x[15], .railComCutoutStart)
        XCTAssertEqual(x[16], .data(word: Int(bitPattern: 0b110000111100001111000011110000) << 2, size: 30))
        XCTAssertEqual(x[17], .railComCutoutEnd)
        XCTAssertEqual(x[18], .debugEnd)
    }
    
    /// Test that we can append a DCC packet for operations mode when using an unusual bit length.
    func testOperationsModePacketAlternateLength() {
        let packet: Packet = .speed28Step(address: 3, direction: .forward, speed: 14) //(bytes: [0b00000011, 0b01111000, 0b01111011])
        
        var x = Bitstream(bitDuration: 10, wordSize: 32)
        x.append(operationsModePacket: packet)
        
        XCTAssertEqual(x.count, 25)
        XCTAssertEqual(x[0],  .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[1],  .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[2],  .data(word: Int(bitPattern: 0b11000000111111000000111111000000), size: 32))
        XCTAssertEqual(x[3],  .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[4],  .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[5],  .data(word: Int(bitPattern: 0b11000000111111111100000000001111), size: 32))
        XCTAssertEqual(x[6],  .data(word: Int(bitPattern: 0b11111100000000001111111111000000), size: 32))
        XCTAssertEqual(x[7],  .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[8],  .data(word: Int(bitPattern: 0b11000000000011111111110000000000), size: 32))
        XCTAssertEqual(x[9],  .data(word: Int(bitPattern: 0b11111111110000000000111111000000), size: 32))
        XCTAssertEqual(x[10], .data(word: Int(bitPattern: 0b11111100000011111111110000000000), size: 32))
        XCTAssertEqual(x[11], .data(word: Int(bitPattern: 0b11111111110000000000111111000000), size: 32))
        XCTAssertEqual(x[12], .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[13], .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[14], .data(word: Int(bitPattern: 0b11000000000011111111110000000000), size: 32))
        XCTAssertEqual(x[15], .data(word: Int(bitPattern: 0b11111111110000000000111111111100), size: 32))
        XCTAssertEqual(x[16], .data(word: Int(bitPattern: 0b00000000111111000000111111000000), size: 32))
        XCTAssertEqual(x[17], .data(word: Int(bitPattern: 0b11111100000011111100000011111111), size: 32))
        XCTAssertEqual(x[18], .data(word: Int(bitPattern: 0b11000000000011111100000011111100), size: 32))
        XCTAssertEqual(x[19], .data(word: Int(bitPattern: 0b0000111111000000111) << 13, size: 19))
        XCTAssertEqual(x[20], .railComCutoutStart)
        XCTAssertEqual(x[21], .data(word: Int(bitPattern: 0b11100000011111100000011111100000), size: 32))
        XCTAssertEqual(x[22], .data(word: Int(bitPattern: 0b01111110000) << 21, size: 11))
        XCTAssertEqual(x[23], .railComCutoutEnd)
        XCTAssertEqual(x[24], .data(word: Int(bitPattern: 0b00) << 30, size: 2))
    }

    /// Test that we can append a DCC packet for operations mode, and debugging, when using an unusual bit length.
    func testOperationsModePacketAlternateLengthWithDebug() {
        let packet: Packet = .speed28Step(address: 3, direction: .forward, speed: 14) //(bytes: [0b00000011, 0b01111000, 0b01111011])
        
        var x = Bitstream(bitDuration: 10, wordSize: 32)
        x.append(operationsModePacket: packet, debug: true)
        
        XCTAssertEqual(x.count, 28)
        XCTAssertEqual(x[0],  .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[1],  .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[2],  .data(word: Int(bitPattern: 0b11000000111111000000111111000000), size: 32))
        XCTAssertEqual(x[3],  .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[4],  .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[5],  .data(word: Int(bitPattern: 0b11000000) << 24, size: 8))
        XCTAssertEqual(x[6],  .debugStart)
        XCTAssertEqual(x[7],  .data(word: Int(bitPattern: 0b11111111110000000000111111111100), size: 32))
        XCTAssertEqual(x[8],  .data(word: Int(bitPattern: 0b00000000111111111100000000001111), size: 32))
        XCTAssertEqual(x[9],  .data(word: Int(bitPattern: 0b11111100000000001111111111000000), size: 32))
        XCTAssertEqual(x[10], .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[11], .data(word: Int(bitPattern: 0b11000000000011111100000011111100), size: 32))
        XCTAssertEqual(x[12], .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[13], .data(word: Int(bitPattern: 0b11000000000011111100000011111100), size: 32))
        XCTAssertEqual(x[14], .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[15], .data(word: Int(bitPattern: 0b11111100000000001111111111000000), size: 32))
        XCTAssertEqual(x[16], .data(word: Int(bitPattern: 0b00001111111111000000000011111111), size: 32))
        XCTAssertEqual(x[17], .data(word: Int(bitPattern: 0b11000000000011111111110000000000), size: 32))
        XCTAssertEqual(x[18], .data(word: Int(bitPattern: 0b11111100000011111100000011111100), size: 32))
        XCTAssertEqual(x[19], .data(word: Int(bitPattern: 0b00001111110000001111111111000000), size: 32))
        XCTAssertEqual(x[20], .data(word: Int(bitPattern: 0b00001111110000001111110000001111), size: 32))
        XCTAssertEqual(x[21], .data(word: Int(bitPattern: 0b11000000111) << 21, size: 11))
        XCTAssertEqual(x[22], .railComCutoutStart)
        XCTAssertEqual(x[23], .data(word: Int(bitPattern: 0b11100000011111100000011111100000), size: 32))
        XCTAssertEqual(x[24], .data(word: Int(bitPattern: 0b01111110000) << 21, size: 11))
        XCTAssertEqual(x[25], .railComCutoutEnd)
        XCTAssertEqual(x[26], .debugEnd)
        XCTAssertEqual(x[27], .data(word: Int(bitPattern: 0b00) << 30, size: 2))
    }

    
    // MARK: duration
    
    /// Test that a duration of an empty bitstream is zero.
    func testDurationEmptyBitstream() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 0)
        
        XCTAssertEqual(x.duration, 0)
    }
    
    /// Test that the duration of a bitstream of a single bit is the bit duration.
    func testDurationSingleBit() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 1)
        
        XCTAssertEqual(x.duration, 14.5)
    }

    /// Test that the duration of a bitstream with a single data entry is calculated.
    func testDurationSingleData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 10)
        
        XCTAssertEqual(x.duration, 145.0)
    }

    /// Test that the duration of a bitstream with a single data entry, combined from different insertions, is calculated.
    func testDurationSingleDataFromMulitpleAppends() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 10)
        x.append(repeatingPhysicalBit: 0, count: 10)

        XCTAssertEqual(x.duration, 290.0)
    }

    /// Test that the duration of a bitstream made up of multiple data entries is calculated.
    func testDurationMultipleData() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 100)
        
        XCTAssertEqual(x.duration, 1450.0)
    }
    
    /// Test that other non-data events are ignored in the bitstream when calculating the duration.
    func testDurationDataBrokenByEvent() {
        var x = Bitstream(bitDuration: 14.5)
        x.append(repeatingPhysicalBit: 1, count: 10)
        x.append(.debugStart)
        x.append(repeatingPhysicalBit: 0, count: 10)

        XCTAssertEqual(x.duration, 290.0)
    }

}
