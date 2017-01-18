//
//  DriverTests.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import XCTest

@testable import RaspberryPi
@testable import DCC

#if os(Linux)
import CBSD
#endif


class DriverTests: XCTestCase {

    var raspberryPi: RaspberryPi!
    var randomWords: [Int] = []

    override func setUp() {
        super.setUp()
        
        raspberryPi = RaspberryPi(peripheralAddress: 0x3f000000, peripheralAddressSize: 0x01000000)
        
        // Generate a set of random word data for testing.
        randomWords.removeAll()
        for _ in 0..<16 {
            randomWords.append(Int(bitPattern: UInt(arc4random_uniform(.max))))
        }
    }
    
    // FIXME: if we stopped arseing around with physical bits, we wouldn't need this function
    func cutData(_ data: Int, to count: Int, wordSize: Int) -> Int {
        return (data & ~(~0 << count)) << (wordSize - count)
    }
    
    func startControlBlock(dataAt dataIndex: Int, next nextIndex: Int) -> DMAControlBlock {
        return DMAControlBlock(
            transferInformation: [ .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * dataIndex,
            destinationAddress: 0,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * nextIndex)
    }
    
    func endControlBlock(dataAt dataIndex: Int, next nextIndex: Int) -> DMAControlBlock {
        return DMAControlBlock(
            transferInformation: [ .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * dataIndex,
            destinationAddress: 0,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * nextIndex)
    }
    
    func dataControlBlock(dataAt dataIndex: Int, length dataLength: Int, next nextIndex: Int) -> DMAControlBlock {
        return DMAControlBlock(
            transferInformation: [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationDREQ, .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * dataIndex,
            destinationAddress: raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset,
            transferLength: MemoryLayout<Int>.stride * dataLength,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * nextIndex)
    }
    
    func rangeControlBlock(rangeAt rangeIndex: Int, next nextIndex: Int) -> DMAControlBlock {
        return DMAControlBlock(
            transferInformation: [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * rangeIndex,
            destinationAddress: raspberryPi.peripheralBusAddress + PWM.offset + PWM.channel1RangeOffset,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * nextIndex)
    }
    
    func gpioControlBlock(dataAt dataIndex: Int, next nextIndex: Int) -> DMAControlBlock {
        return DMAControlBlock(
            transferInformation: [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationAddressIncrement, .destinationDREQ, .tdMode, .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * dataIndex,
            destinationAddress: raspberryPi.peripheralBusAddress + GPIO.offset + GPIO.outputSetOffset,
            transferLength: DMAControlBlock.tdTransferLength(x: MemoryLayout<Int>.stride * 2, y: 2),
            tdModeStride: DMAControlBlock.tdModeStride(source: 0, destination: MemoryLayout<Int>.stride),
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * nextIndex)
    }
    
    
    // MARK: Data
    
    /// Test that a bitstream containing a single word outputs a control block writing it to the fifo.
    ///
    /// The first word is always followed by a range matching its size.
    func testParsedBitstreamSingleWord() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 4)
        XCTAssertEqual(parsed.data.count, 5)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)

        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])

        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], endControlBlock(dataAt: 4, next: 1))
        XCTAssertEqual(parsed.data[4], -1)

    }
    
    /// Test that a bitstream containing two words outputs two control blocks to write each one to the fifo.
    ///
    /// The first word is followed by the range as for a single word, but the second word shouldn't need one when the range is the same.
    func testParsedBitstreamSecondWordSameSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)

        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 5)
        XCTAssertEqual(parsed.data.count, 6)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])

        XCTAssertEqual(parsed.controlBlocks[4], endControlBlock(dataAt: 5, next: 1))
        XCTAssertEqual(parsed.data[5], -1)

    }
    
    /// Test that a bitstream containing two words of different sizes also outputs an extra range change.
    ///
    /// Both words should be followed by a range.
    func testParsedBitstreamSecondWordDifferentSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 24)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 7)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], cutData(randomWords[1], to: 24, wordSize: 32))
        
        XCTAssertEqual(parsed.controlBlocks[4], rangeControlBlock(rangeAt: 5, next: 5))
        XCTAssertEqual(parsed.data[5], 24)

        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 6, next: 1))
        XCTAssertEqual(parsed.data[6], -1)

    }

    /// Test that a bitstream containing three words outputs only two control blocks, the second with a longer data.
    ///
    /// Multiple same-size writes are merged into a single control block.
    func testParsedBitstreamThirdWordSameSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)

        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 5)
        XCTAssertEqual(parsed.data.count, 7)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])

        XCTAssertEqual(parsed.controlBlocks[4], endControlBlock(dataAt: 6, next: 1))
        XCTAssertEqual(parsed.data[6], -1)

    }

    /// Test that a bitstream containing three words outputs with the third a different size, follows it with a range.
    ///
    /// Multiple are still merged into a single control block, with the first of a different size followed by a range.
    func testParsedBitstreamThirdWordDifferentSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 24)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 8)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], cutData(randomWords[2], to: 24, wordSize: 32))
        
        XCTAssertEqual(parsed.controlBlocks[4], rangeControlBlock(rangeAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 24)

        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 7, next: 1))
        XCTAssertEqual(parsed.data[7], -1)

    }
    
    
    // MARK: GPIO Events
    
    /// Test that a GPIO event is output two PWM words after its actual position in the bitstream using a GPIO control block.
    func testParsedBitstreamGPIOEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 11)

        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)

        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])

        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 1 << 19)
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 0)

        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 10, next: 1))
        XCTAssertEqual(parsed.data[10], -1)

    }

    /// Test that multiple GPIO set events are combined into a single control block.
    func testParsedBitstreamMultipleGPIOSetEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.railComCutoutEnd)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 11)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 1 << 19 | 1 << 17)
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 0)
        
        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 10, next: 1))
        XCTAssertEqual(parsed.data[10], -1)

    }

    /// Test that multiple GPIO clear events are combined into a single control block.
    func testParsedBitstreamMultipleGPIOClearEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.railComCutoutStart)
        bitstream.append(.debugEnd)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 11)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 0)
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 1 << 19 | 1 << 17)
        XCTAssertEqual(parsed.data[9], 0)
        
        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 10, next: 1))
        XCTAssertEqual(parsed.data[10], -1)

    }

    /// Test that GPIO set and clear events are combined into a single control block.
    func testParsedBitstreamMultipleGPIOEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.railComCutoutEnd)
        bitstream.append(.debugEnd)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 11)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 1 << 17)
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 1 << 19)
        XCTAssertEqual(parsed.data[9], 0)
        
        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 10, next: 1))
        XCTAssertEqual(parsed.data[10], -1)

    }

    /// Test that when multiple GPIO events for the same GPIO end up in the same control block, the most recent one wins.
    ///
    /// Rather than have four separate test cases for this, we test all the combinations in two non-conflicting groups.
    func testParsedBitstreamMultipleGPIOLastWins() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.railComCutoutStart)
        bitstream.append(.railComCutoutEnd)
        bitstream.append(.debugStart)
        bitstream.append(.debugEnd)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.railComCutoutEnd)
        bitstream.append(.railComCutoutStart)
        bitstream.append(.debugEnd)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)

        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 16)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 1 << 17) // railComCutoutEnd wins
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 1 << 19) // debugEnd wins
        XCTAssertEqual(parsed.data[9], 0)
        
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 10, length: 1, next: 6))
        XCTAssertEqual(parsed.data[10], randomWords[3])

        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 11, next: 7))
        XCTAssertEqual(parsed.data[11], 1 << 19) // debugStart wins
        XCTAssertEqual(parsed.data[12], 0)
        XCTAssertEqual(parsed.data[13], 1 << 17) // railComCutoutStart wins
        XCTAssertEqual(parsed.data[14], 0)

        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 15, next: 1))
        XCTAssertEqual(parsed.data[15], -1)

    }

    /// Test that a GPIO event breaks data when it needs to appear.
    func testParsedBitstreamGPIOEventBreaksData() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)

        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 7)
        XCTAssertEqual(parsed.data.count, 12)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 1 << 19)
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 0)
        
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 10, length: 1, next: 6))
        XCTAssertEqual(parsed.data[10], randomWords[3])

        XCTAssertEqual(parsed.controlBlocks[6], endControlBlock(dataAt: 11, next: 1))
        XCTAssertEqual(parsed.data[11], -1)

    }
    
    
    // MARK: GPIO Event loop unrolling
    
    /// Test that if a GPIO event appears towards the end of the Bitstream, we compensate by unrolling the loop until we're caught up and can insert a later jump.
    func testParsedBitstreamGPIOEventUnrollsLoop() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)

        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)

        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 12)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // Length is longer because the loop is being unrolled at this point, and there's no range change to break it.
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 3, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.data[6], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 7, next: 5))
        XCTAssertEqual(parsed.data[7], 1 << 19)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 0)
        XCTAssertEqual(parsed.data[10], 0)
        
        // Loop no longer needs to be unrolled, since we found a previous data block we can jump to.
        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 11, next: 3))
        XCTAssertEqual(parsed.data[11], -1)

    }
    
    /// Test that a loop can be unrolled even when a GPIO event would be pending across the loop index.
    func testParsedBitstreamGPIOEventUnrollsLoopAcrossOtherGPIOEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.railComCutoutStart)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 16)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])

        // Initial delayed RailCom cutout block.
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 5, next: 5))
        XCTAssertEqual(parsed.data[5], 0)
        XCTAssertEqual(parsed.data[6], 0)
        XCTAssertEqual(parsed.data[7], 1 << 17)
        XCTAssertEqual(parsed.data[8], 0)
        
        // Length is longer because the loop is being unrolled at this point, and there's no range change to break it.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 9, length: 2, next: 6))
        XCTAssertEqual(parsed.data[9], randomWords[2])
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.data[10], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 11, next: 7))
        XCTAssertEqual(parsed.data[11], 1 << 19)
        XCTAssertEqual(parsed.data[12], 0)
        XCTAssertEqual(parsed.data[13], 0)
        XCTAssertEqual(parsed.data[14], 0)
        
        // Loop no longer needs to be unrolled, since we found a previous data block we can jump to.
        // The fact we have a currently delayed .railComCutoutStart isn't relevant because so did the previous loop iteration so we can assume it's in the right place.
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 15, next: 3))
        XCTAssertEqual(parsed.data[15], -1)

    }

    /// Test that a loop can be unrolled even when the GPIO event appears right at the end.
    func testParsedBitstreamGPIOEventAtEndUnrollsLoop() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.railComCutoutStart)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(.debugStart)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 17)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        
        // Initial delayed RailCom cutout block.
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 5, next: 5))
        XCTAssertEqual(parsed.data[5], 0)
        XCTAssertEqual(parsed.data[6], 0)
        XCTAssertEqual(parsed.data[7], 1 << 17)
        XCTAssertEqual(parsed.data[8], 0)
        
        // Length is longer because the loop is being unrolled at this point, and there's no range change to break it.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 9, length: 3, next: 6))
        XCTAssertEqual(parsed.data[9], randomWords[2])
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.data[10], randomWords[0])
        XCTAssertEqual(parsed.data[11], randomWords[1])
        
        // GPIO control block now includes both GPIO events.
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 12, next: 7))
        XCTAssertEqual(parsed.data[12], 1 << 19)
        XCTAssertEqual(parsed.data[13], 0)
        XCTAssertEqual(parsed.data[14], 1 << 17)
        XCTAssertEqual(parsed.data[15], 0)
        
        // Loop no longer needs to be unrolled, since we found a previous data block we can jump to.
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 16, next: 5))
        XCTAssertEqual(parsed.data[16], -1)

    }
    
    /// Test that a loop can be unrolled twice when necessary to synchronize back with a delayed event.
    func testParsedBitstreamGPIOEventUnrollsLoopTwice() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(.debugStart)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 20)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // The first time through unrolls the loop and places the GPIO event at the correct point (after 1).
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 4, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.data[6], randomWords[0])
        XCTAssertEqual(parsed.data[7], randomWords[1])

        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 8, next: 5))
        XCTAssertEqual(parsed.data[8], 1 << 19)
        XCTAssertEqual(parsed.data[9], 0)
        XCTAssertEqual(parsed.data[10], 0)
        XCTAssertEqual(parsed.data[11], 0)

        // The second time through has to unroll the loop again since the previous block begins at the wrong point.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 12, length: 3, next: 6))
        XCTAssertEqual(parsed.data[12], randomWords[2])
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.data[13], randomWords[0])
        XCTAssertEqual(parsed.data[14], randomWords[1])
        
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 15, next: 7))
        XCTAssertEqual(parsed.data[15], 1 << 19)
        XCTAssertEqual(parsed.data[16], 0)
        XCTAssertEqual(parsed.data[17], 0)
        XCTAssertEqual(parsed.data[18], 0)
        
        // Now we have a control block sequence that we can repeat.
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 19, next: 5))
        XCTAssertEqual(parsed.data[19], -1)

    }

    /// Test that a loop is unrolled twice rather than resetting back to the start.
    func testParsedBitstreamGPIOEventUnrollsLoopTwiceNotToStart() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 18)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // The first time through unrolls the loop and places the GPIO event at the correct point (after 1).
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 3, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.data[5], randomWords[0])
        XCTAssertEqual(parsed.data[6], randomWords[1])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 7, next: 5))
        XCTAssertEqual(parsed.data[7], 1 << 19)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 0)
        XCTAssertEqual(parsed.data[10], 0)
        
        // The second time through has to unroll the loop again since returning to the start wouldn't include the delayed event.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 11, length: 2, next: 6))
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.data[11], randomWords[0])
        XCTAssertEqual(parsed.data[12], randomWords[1])
        
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 13, next: 7))
        XCTAssertEqual(parsed.data[13], 1 << 19)
        XCTAssertEqual(parsed.data[14], 0)
        XCTAssertEqual(parsed.data[15], 0)
        XCTAssertEqual(parsed.data[16], 0)
        
        // Now we have a control block sequence that we can repeat.
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 17, next: 5))
        XCTAssertEqual(parsed.data[17], -1)

    }

    /// Test that a loop unroll will repeat a single piece of data if necessary to synchornize.
    func testParsedBitstreamGPIOEventUnrollsLoopRepeatingData() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 16)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // To unroll the loop, it has to repeat the first data entry.
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[0])
        XCTAssertEqual(parsed.data[5], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[4], gpioControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], 1 << 19)
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 0)
        
        // Now every other data is followed by a GPIO event, so it repeats a single data, and the GPIO event again.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 10, length: 1, next: 6))
        XCTAssertEqual(parsed.data[10], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 11, next: 7))
        XCTAssertEqual(parsed.data[11], 1 << 19)
        XCTAssertEqual(parsed.data[12], 0)
        XCTAssertEqual(parsed.data[13], 0)
        XCTAssertEqual(parsed.data[14], 0)
        
        // Now we have a control block sequence that we can repeat.
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 15, next: 5))
        XCTAssertEqual(parsed.data[15], -1)

    }

    
    // MARK: Repeating Sections
    
    /// Test that a bitstream with a marked repeating section loops to the start of that section, not the start of the bitstream.
    ///
    /// The data should be broken at the loop point, and the end control block pointed after it rather than to the first.
    func testParsedBitstreamWithRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)

        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 6)
        XCTAssertEqual(parsed.data.count, 8)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])

        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // This data should be broken due to the loop point.
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        
        // This is the repeating part.
        XCTAssertEqual(parsed.controlBlocks[4], dataControlBlock(dataAt: 5, length: 2, next: 5))
        XCTAssertEqual(parsed.data[5], randomWords[2])
        XCTAssertEqual(parsed.data[6], randomWords[3])
        
        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 7, next: 4))
        XCTAssertEqual(parsed.data[7], -1)

    }
    
    /// Test that an unrolled loop unrolls into the repeating section and not the start.
    func testParsedBitstreamGPIOEventUnrollsToRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(.railComCutoutStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[4], count: 32)
        
        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 11)
        XCTAssertEqual(parsed.data.count, 23)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        
        // Break here for the repeating section.
        
        // Second half leading up to the RailCom GPIO event.
        XCTAssertEqual(parsed.controlBlocks[4], dataControlBlock(dataAt: 5, length: 2, next: 5))
        XCTAssertEqual(parsed.data[5], randomWords[2])
        XCTAssertEqual(parsed.data[6], randomWords[3])

        XCTAssertEqual(parsed.controlBlocks[5], gpioControlBlock(dataAt: 7, next: 6))
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 1 << 17)
        XCTAssertEqual(parsed.data[10], 0)
        
        // Now the length goes over the end, but not to the 0th word, but the 2nd.
        XCTAssertEqual(parsed.controlBlocks[6], dataControlBlock(dataAt: 11, length: 2, next: 7))
        XCTAssertEqual(parsed.data[11], randomWords[4])
        // Unroll of loop to the repeating section begins here.
        XCTAssertEqual(parsed.data[12], randomWords[2])

        XCTAssertEqual(parsed.controlBlocks[7], gpioControlBlock(dataAt: 13, next: 8))
        XCTAssertEqual(parsed.data[13], 1 << 19)
        XCTAssertEqual(parsed.data[14], 0)
        XCTAssertEqual(parsed.data[15], 0)
        XCTAssertEqual(parsed.data[16], 0)
        
        // Loop can't immediately complete because we're midway through a data that existed the first time around, so we have to finish that, which means repeating the RailCom GPIO.
        XCTAssertEqual(parsed.controlBlocks[8], dataControlBlock(dataAt: 17, length: 1, next: 9))
        XCTAssertEqual(parsed.data[17], randomWords[3])
        
        XCTAssertEqual(parsed.controlBlocks[9], gpioControlBlock(dataAt: 18, next: 10))
        XCTAssertEqual(parsed.data[18], 0)
        XCTAssertEqual(parsed.data[19], 0)
        XCTAssertEqual(parsed.data[20], 1 << 17)
        XCTAssertEqual(parsed.data[21], 0)
        
        // Now we've reached the start of a data block we can use to loop.
        XCTAssertEqual(parsed.controlBlocks[10], endControlBlock(dataAt: 22, next: 6))
        XCTAssertEqual(parsed.data[22], -1)

    }

    /// Test that when a GPIO event is delayed across a repeating section start, that itself is unrolled in order to repeat without it.
    func testParsedBitstreamGPIOEventUnrollsWhenAcrossRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)

        let parsed = try! ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 13)
        
        XCTAssertEqual(parsed.data[0], 0)

        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        
        // Break here for the repeating section.

        XCTAssertEqual(parsed.controlBlocks[4], dataControlBlock(dataAt: 5, length: 1, next: 5))
        XCTAssertEqual(parsed.data[5], randomWords[2])

        XCTAssertEqual(parsed.controlBlocks[5], gpioControlBlock(dataAt: 6, next: 6))
        XCTAssertEqual(parsed.data[6], 1 << 19)
        XCTAssertEqual(parsed.data[7], 0)
        XCTAssertEqual(parsed.data[8], 0)
        XCTAssertEqual(parsed.data[9], 0)

        // Now the length goes over the end, but not to the 0th word, but the 2nd.
        XCTAssertEqual(parsed.controlBlocks[6], dataControlBlock(dataAt: 10, length: 2, next: 7))
        XCTAssertEqual(parsed.data[10], randomWords[3])
        // Unroll of loop to the repeating section begins here.
        XCTAssertEqual(parsed.data[11], randomWords[2])

        // We can now repeat that last data block without the extra part in there.
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 12, next: 6))
        XCTAssertEqual(parsed.data[12], -1)

    }
    
    
    // MARK: Errors
    
    /// Test that an empty bitstream throws an error.
    func testParseEmptyBitstream() {
        let bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        
        do {
            let _ = try ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
            XCTFail("Parsing should not have been successful")
        } catch DriverError.bitstreamContainsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown")
        }
    }

    /// Test that a bitstream without any data throws an error.
    func testParsedBitstreamWithoutData() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.debugStart)
        
        do {
            let _ = try ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
            XCTFail("Parsing should not have been successful")
        } catch DriverError.bitstreamContainsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown")
        }
    }
    
    /// Test that a bitstream with nothing following a repeating section start throws an error.
    func testParsedBitstreamWithEmptyRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        
        do {
            let _ = try ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
            XCTFail("Parsing should not have been successful")
        } catch DriverError.bitstreamContainsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    /// Test that a bitstream with no data following a repeating section start throws an error.
    func testParsedBitstreamWithoutDataInRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(.debugStart)
        
        do {
            let _ = try ParsedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
            XCTFail("Parsing should not have been successful")
        } catch DriverError.bitstreamContainsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

}

extension DriverTests {
    
    static var allTests = {
        return [
            ("testParsedBitstreamSingleWord", testParsedBitstreamSingleWord),
            ("testParsedBitstreamSecondWordSameSize", testParsedBitstreamSecondWordSameSize),
            ("testParsedBitstreamSecondWordDifferentSize", testParsedBitstreamSecondWordDifferentSize),
            ("testParsedBitstreamThirdWordSameSize", testParsedBitstreamThirdWordSameSize),
            ("testParsedBitstreamThirdWordDifferentSize", testParsedBitstreamThirdWordDifferentSize),
            
            ("testParsedBitstreamGPIOEvent", testParsedBitstreamGPIOEvent),
            ("testParsedBitstreamMultipleGPIOSetEvent", testParsedBitstreamMultipleGPIOSetEvent),
            ("testParsedBitstreamMultipleGPIOClearEvent", testParsedBitstreamMultipleGPIOClearEvent),
            ("testParsedBitstreamMultipleGPIOEvent", testParsedBitstreamMultipleGPIOEvent),
            ("testParsedBitstreamMultipleGPIOLastWins", testParsedBitstreamMultipleGPIOLastWins),
            ("testParsedBitstreamGPIOEventBreaksData", testParsedBitstreamGPIOEventBreaksData),
            
            ("testParsedBitstreamGPIOEventUnrollsLoop", testParsedBitstreamGPIOEventUnrollsLoop),
            ("testParsedBitstreamGPIOEventUnrollsLoopAcrossOtherGPIOEvent", testParsedBitstreamGPIOEventUnrollsLoopAcrossOtherGPIOEvent),
            ("testParsedBitstreamGPIOEventAtEndUnrollsLoop", testParsedBitstreamGPIOEventAtEndUnrollsLoop),
            ("testParsedBitstreamGPIOEventUnrollsLoopTwice", testParsedBitstreamGPIOEventUnrollsLoopTwice),
            ("testParsedBitstreamGPIOEventUnrollsLoopTwiceNotToStart", testParsedBitstreamGPIOEventUnrollsLoopTwiceNotToStart),
            ("testParsedBitstreamGPIOEventUnrollsLoopRepeatingData", testParsedBitstreamGPIOEventUnrollsLoopRepeatingData),
            
            ("testParsedBitstreamWithRepeatingSection", testParsedBitstreamWithRepeatingSection),
            ("testParsedBitstreamWithEmptyRepeatingSection", testParsedBitstreamWithEmptyRepeatingSection),
            ("testParsedBitstreamGPIOEventUnrollsToRepeatingSection", testParsedBitstreamGPIOEventUnrollsToRepeatingSection),
            ("testParsedBitstreamGPIOEventUnrollsWhenAcrossRepeatingSection", testParsedBitstreamGPIOEventUnrollsWhenAcrossRepeatingSection),
            
            ("testParseEmptyBitstream", testParseEmptyBitstream),
            ("testParsedBitstreamWithoutData", testParsedBitstreamWithoutData),
            ("testParsedBitstreamWithEmptyRepeatingSection", testParsedBitstreamWithEmptyRepeatingSection),
            ("testParsedBitstreamWithoutDataInRepeatingSection", testParsedBitstreamWithoutDataInRepeatingSection),
        ]
    }()

}
