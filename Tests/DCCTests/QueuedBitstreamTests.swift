//
//  QueuedBitstreamTests.swift
//  SignalBox
//
//  Created by Scott James Remnant on 2/1/17.
//
//

import XCTest

@testable import RaspberryPi
@testable import DCC

#if os(Linux)
import CBSD
#endif


class QueuedBitstreamTests : XCTestCase {
    
    var raspberryPi: RaspberryPi!
    var randomWords: [Int] = []
    
    override func setUp() {
        super.setUp()
        
        raspberryPi = TestRaspberryPi(peripheralAddress: 0x3f000000, peripheralSize: 0x01000000)
        
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
    func testParseBitstreamSingleWord() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamSecondWordSameSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamSecondWordDifferentSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 24)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamThirdWordSameSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamThirdWordDifferentSize() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 24)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    
    
    // MARK: Return value
    
    /// Test that the return value for the first call is zero.
    func testParseBitstreamReturnValue() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        let offset = try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(offset, 0)
    }
    
    /// Test that the return value for a second call is the previous count of control blocks.
    func testParseBitstreamSecondCallReturnValue() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        let expectedOffset = parsed.controlBlocks.count
        
        let offset = try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(offset, expectedOffset)
    }

    
    
    // MARK: GPIO Events
    
    /// Test that a GPIO event is output two PWM words after its actual position in the bitstream using a GPIO control block.
    func testParseBitstreamGPIOEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamMultipleGPIOSetEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.railComCutoutEnd)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamMultipleGPIOClearEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.railComCutoutStart)
        bitstream.append(.debugEnd)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamMultipleGPIOEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.railComCutoutEnd)
        bitstream.append(.debugEnd)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamMultipleGPIOLastWins() {
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
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamGPIOEventBreaksData() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamGPIOEventUnrollsLoop() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[4], endControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], -1)
        
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 7, length: 1, next: 6))
        XCTAssertEqual(parsed.data[7], randomWords[0])
        
        // After this, loop can return to the previous data block.
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 8, next: 3))
        XCTAssertEqual(parsed.data[8], 1 << 19)
        XCTAssertEqual(parsed.data[9], 0)
        XCTAssertEqual(parsed.data[10], 0)
        XCTAssertEqual(parsed.data[11], 0)
    }
    
    /// Test that a loop can be unrolled even when a GPIO event would be pending across the loop index.
    func testParseBitstreamGPIOEventUnrollsLoopAcrossOtherGPIOEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.railComCutoutStart)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 9)
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
        
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 9, length: 1, next: 6))
        XCTAssertEqual(parsed.data[9], randomWords[2])
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[6], endControlBlock(dataAt: 10, next: 7))
        XCTAssertEqual(parsed.data[10], -1)
        
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.controlBlocks[7], dataControlBlock(dataAt: 11, length: 1, next: 8))
        XCTAssertEqual(parsed.data[11], randomWords[0])
        
        // After this, loop can return to the previous data block.
        // The fact we have a currently delayed .railComCutoutStart isn't relevant because so did the previous loop iteration so we can assume it's in the right place.
        XCTAssertEqual(parsed.controlBlocks[8], gpioControlBlock(dataAt: 12, next: 3))
        XCTAssertEqual(parsed.data[12], 1 << 19)
        XCTAssertEqual(parsed.data[13], 0)
        XCTAssertEqual(parsed.data[14], 0)
        XCTAssertEqual(parsed.data[15], 0)
    }
    
    /// Test that a loop can be unrolled even when the GPIO event appears right at the end.
    func testParseBitstreamGPIOEventAtEndUnrollsLoop() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.railComCutoutStart)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(.debugStart)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 9)
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
        
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 9, length: 1, next: 6))
        XCTAssertEqual(parsed.data[9], randomWords[2])
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[6], endControlBlock(dataAt: 10, next: 7))
        XCTAssertEqual(parsed.data[10], -1)
        
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.controlBlocks[7], dataControlBlock(dataAt: 11, length: 2, next: 8))
        XCTAssertEqual(parsed.data[11], randomWords[0])
        XCTAssertEqual(parsed.data[12], randomWords[1])
        
        // GPIO control block now includes both GPIO events.
        // After this, loop can return to the previous data block.
        XCTAssertEqual(parsed.controlBlocks[8], gpioControlBlock(dataAt: 13, next: 5))
        XCTAssertEqual(parsed.data[13], 1 << 19)
        XCTAssertEqual(parsed.data[14], 0)
        XCTAssertEqual(parsed.data[15], 1 << 17)
        XCTAssertEqual(parsed.data[16], 0)
    }
    
    /// Test that a loop can be unrolled twice when necessary to synchronize back with a delayed event.
    func testParseBitstreamGPIOEventUnrollsLoopTwice() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(.debugStart)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 9)
        XCTAssertEqual(parsed.data.count, 15)
        
        XCTAssertEqual(parsed.data[0], 0)
        
        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // The first time through unrolls the loop and places the GPIO event at the correct point (after 1).
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 2, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        XCTAssertEqual(parsed.data[5], randomWords[2])
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[4], endControlBlock(dataAt: 6, next: 5))
        XCTAssertEqual(parsed.data[6], -1)
        
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 7, length: 2, next: 6))
        XCTAssertEqual(parsed.data[7], randomWords[0])
        XCTAssertEqual(parsed.data[8], randomWords[1])
        
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 9, next: 7))
        XCTAssertEqual(parsed.data[9], 1 << 19)
        XCTAssertEqual(parsed.data[10], 0)
        XCTAssertEqual(parsed.data[11], 0)
        XCTAssertEqual(parsed.data[12], 0)
        
        XCTAssertEqual(parsed.controlBlocks[7], dataControlBlock(dataAt: 13, length: 1, next: 8))
        XCTAssertEqual(parsed.data[13], randomWords[2])
        
        // End of second loop.
        // Now we've completely output the second loop, we can return back to the start of its own unrolling.
        XCTAssertEqual(parsed.controlBlocks[8], endControlBlock(dataAt: 14, next: 5))
        XCTAssertEqual(parsed.data[14], -1)
    }
    
    /// Test that a loop is unrolled twice rather than resetting back to the start.
    func testParseBitstreamGPIOEventUnrollsLoopTwiceNotToStart() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 8)
        XCTAssertEqual(parsed.data.count, 13)
        
        XCTAssertEqual(parsed.data[0], 0)
        
        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // The first time through unrolls the loop and places the GPIO event at the correct point (after 1).
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 1, next: 4))
        XCTAssertEqual(parsed.data[4], randomWords[1])
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[4], endControlBlock(dataAt: 5, next: 5))
        XCTAssertEqual(parsed.data[5], -1)
        
        // Unroll of loop begins here.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 6, length: 2, next: 6))
        XCTAssertEqual(parsed.data[6], randomWords[0])
        XCTAssertEqual(parsed.data[7], randomWords[1])
        
        // With the GPIO output, this time we can repeat the unrolling that consists simply of the data and the GPIO.
        XCTAssertEqual(parsed.controlBlocks[6], gpioControlBlock(dataAt: 8, next: 7))
        XCTAssertEqual(parsed.data[8], 1 << 19)
        XCTAssertEqual(parsed.data[9], 0)
        XCTAssertEqual(parsed.data[10], 0)
        XCTAssertEqual(parsed.data[11], 0)
        
        // End of second loop
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 12, next: 5))
        XCTAssertEqual(parsed.data[12], -1)
    }
    
    /// Test that a loop unroll will repeat a single piece of data if necessary to synchornize.
    func testParseBitstreamGPIOEventUnrollsLoopRepeatingData() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 9)
        XCTAssertEqual(parsed.data.count, 13)
        
        XCTAssertEqual(parsed.data[0], 0)
        
        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], randomWords[0])
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[3], endControlBlock(dataAt: 4, next: 4))
        XCTAssertEqual(parsed.data[4], -1)
        
        // To unroll the loop, it has to repeat the first data entry twice to catch up with the delayed event.
        XCTAssertEqual(parsed.controlBlocks[4], dataControlBlock(dataAt: 5, length: 1, next: 5))
        XCTAssertEqual(parsed.data[5], randomWords[0])
        
        // End of second loop
        XCTAssertEqual(parsed.controlBlocks[5], endControlBlock(dataAt: 6, next: 6))
        XCTAssertEqual(parsed.data[6], -1)
        
        XCTAssertEqual(parsed.controlBlocks[6], dataControlBlock(dataAt: 7, length: 1, next: 7))
        XCTAssertEqual(parsed.data[7], randomWords[0])
        
        // Now we've output enough data to do the GPIO event.
        XCTAssertEqual(parsed.controlBlocks[7], gpioControlBlock(dataAt: 8, next: 8))
        XCTAssertEqual(parsed.data[8], 1 << 19)
        XCTAssertEqual(parsed.data[9], 0)
        XCTAssertEqual(parsed.data[10], 0)
        XCTAssertEqual(parsed.data[11], 0)
        
        // End of third loop. Now each loop is a single data followed by a GPIO event, so we can loop back to that entry.
        XCTAssertEqual(parsed.controlBlocks[8], endControlBlock(dataAt: 12, next: 6))
        XCTAssertEqual(parsed.data[12], -1)
    }
    
    /// Test that a loop is not repeated, and the last value set to zero, if repeating is set to true.
    func testParseBitstreamRepeating() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)

        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream, repeating: false)
        
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
        
        XCTAssertEqual(parsed.controlBlocks[4], endControlBlock(dataAt: 5, next: 0))
        XCTAssertEqual(parsed.data[5], -1)
    }
    
    /// Test that a loop is not unrolled even if there are delayed events, if repeating is set to true.
    ///
    /// The breakpoint will have the delayedEvents.
    func testParseBitstreamRepeatingDoesntUnroll() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)

        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream, repeating: false)
        
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
        
        XCTAssertEqual(parsed.controlBlocks[4], endControlBlock(dataAt: 5, next: 0))
        XCTAssertEqual(parsed.data[5], -1)
    }

    
    // MARK: Repeating Sections
    
    /// Test that a bitstream with a marked repeating section loops to the start of that section, not the start of the bitstream.
    ///
    /// The data should be broken at the loop point, and the end control block pointed after it rather than to the first.
    func testParseBitstreamWithRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)
        
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
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
    func testParseBitstreamGPIOEventUnrollsToRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(.railComCutoutStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[4], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 12)
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
        XCTAssertEqual(parsed.controlBlocks[6], dataControlBlock(dataAt: 11, length: 1, next: 7))
        XCTAssertEqual(parsed.data[11], randomWords[4])
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 12, next: 8))
        XCTAssertEqual(parsed.data[12], -1)
        
        // Repeating section begins here.
        XCTAssertEqual(parsed.controlBlocks[8], dataControlBlock(dataAt: 13, length: 1, next: 9))
        XCTAssertEqual(parsed.data[13], randomWords[2])
        
        XCTAssertEqual(parsed.controlBlocks[9], gpioControlBlock(dataAt: 14, next: 10))
        XCTAssertEqual(parsed.data[14], 1 << 19)
        XCTAssertEqual(parsed.data[15], 0)
        XCTAssertEqual(parsed.data[16], 0)
        XCTAssertEqual(parsed.data[17], 0)
        
        // Loop can't immediately complete because we're midway through a data that existed the first time around, so we have to finish that, which means repeating the RailCom GPIO, and then looping.
        XCTAssertEqual(parsed.controlBlocks[10], dataControlBlock(dataAt: 18, length: 1, next: 11))
        XCTAssertEqual(parsed.data[18], randomWords[3])
        
        XCTAssertEqual(parsed.controlBlocks[11], gpioControlBlock(dataAt: 19, next: 6))
        XCTAssertEqual(parsed.data[19], 0)
        XCTAssertEqual(parsed.data[20], 0)
        XCTAssertEqual(parsed.data[21], 1 << 17)
        XCTAssertEqual(parsed.data[22], 0)
    }
    
    /// Test that when a GPIO event is delayed across a repeating section start, that itself is unrolled in order to repeat without it.
    func testParseBitstreamGPIOEventUnrollsWhenAcrossRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 9)
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
        XCTAssertEqual(parsed.controlBlocks[6], dataControlBlock(dataAt: 10, length: 1, next: 7))
        XCTAssertEqual(parsed.data[10], randomWords[3])
        
        // End of first loop
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 11, next: 8))
        XCTAssertEqual(parsed.data[11], -1)
        
        // Unroll of loop to the repeating section begins here.
        // We can now repeat that last data block without the extra part in there.
        XCTAssertEqual(parsed.controlBlocks[8], dataControlBlock(dataAt: 12, length: 1, next: 6))
        XCTAssertEqual(parsed.data[12], randomWords[2])
    }
    
    
    // MARK: Breakpoints
    
    /// Test that a breakpoint is automatically placed pointing at the end control block.
    func testParseBitstreamWithBreakpointAtEnd() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)

        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)

        XCTAssertEqual(parsed.breakpoints.count, 1)
        
        let breakpoint = parsed.breakpoints[0]
        
        // Make sure it's an end control block.
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        let dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)

        // Verify the range is correct and delayed events is empty.
        XCTAssertEqual(breakpoint.range, 32)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents())
    }
    
    /// Test that a breakpoint at the end carries any alternate range.
    func testParseBitstreamWithBreakpointAtEndAfterRange() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 24)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.breakpoints.count, 1)
        
        let breakpoint = parsed.breakpoints[0]
        
        // Make sure it's an end control block.
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        let dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)
        
        // Verify the range is correct and delayed events is empty.
        XCTAssertEqual(breakpoint.range, 24)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents())
    }
    
    /// Test that a breakpoint at the end carries any delayed GPIO events.
    ///
    /// The GPIO event isn't exactly at the end to avoid the case where loop unrolling leaves us with two copies of the end breakpoint.
    func testParseBitstreamWithBreakpointAtEndAfterDelayedEvents() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(.debugEnd)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.breakpoints.count, 1)
        
        let breakpoint = parsed.breakpoints[0]
        
        // Make sure it's an end control block.
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        let dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)
        
        // Verify the range is correct and delayed events is empty.
        XCTAssertEqual(breakpoint.range, 32)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents(events: [(event: .debugEnd, delay: 1)]))
    }
    
    /// Test that when the end control block is duplicated by GPIO events, the breakpoint is duplicated too.
    func testParseBitstreamWithBreakpointAtMultipleEndsAfterDelayedEvents() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugEnd)

        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.breakpoints.count, 2)
        
        var breakpoint = parsed.breakpoints[0]
        
        // Make sure it's an end control block.
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        var dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)
        
        // Verify the range is correct and delayed events is empty.
        XCTAssertEqual(breakpoint.range, 32)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents(events: [(event: .debugEnd, delay: 2)]))
        
        // The second should also be an end control block, and otherwise identical.
        breakpoint = parsed.breakpoints[1]
        
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)
        
        XCTAssertEqual(breakpoint.range, 32)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents(events: [(event: .debugEnd, delay: 2)]))
    }
    
    /// Test that we can also insert a breakpoint wherever we want.
    ///
    /// The breakpoint is attached to the previous event, since that's what will have its nextControlBlockAddress changed.
    func testParseBitstreamWithBreakpoint() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.breakpoint)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.breakpoints.count, 2)

        var breakpoint = parsed.breakpoints[0]
        
        // It should be attached to the previous data.
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset)
        var dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], randomWords[1])
        
        // Verify the range is correct and delayed events is empty.
        XCTAssertEqual(breakpoint.range, 32)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents())
        
        // The second should be for the end control block.
        breakpoint = parsed.breakpoints[1]
        
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)
    }
    
    /// Test that we can insert a breakpoint after a data with an alternate range.
    ///
    /// The breakpoint actually gets attached to the range change, and carries the new range within it.
    func testParseBitstreamWithBreakpointAfterRange() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 24)
        bitstream.append(.breakpoint)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.breakpoints.count, 2)
        
        var breakpoint = parsed.breakpoints[0]
        
        // It should be attached to the previous data's range change.
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, raspberryPi.peripheralBusAddress + PWM.offset + PWM.channel1RangeOffset)
        var dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], 24)
        
        // Verify the range is correct and delayed events is empty.
        XCTAssertEqual(breakpoint.range, 24)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents())
        
        // The second should be for the end control block.
        breakpoint = parsed.breakpoints[1]
        
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)
    }
    
    /// Test that we can insert a breakpoint after a GPIO event.
    ///
    /// The breakpoint gets attached to the data before it, but carries the delayed event with in itself.
    func testParseBitstreamWithBreakpointAfterDelayedEvent() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.debugStart)
        bitstream.append(.breakpoint)
        bitstream.append(physicalBits: randomWords[2], count: 32)
        bitstream.append(physicalBits: randomWords[3], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.breakpoints.count, 2)
        
        var breakpoint = parsed.breakpoints[0]
        
        // It should be attached to the previous data.
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset)
        var dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], randomWords[1])
        
        // Verify the range is correct and delayed event carries the debug start.
        XCTAssertEqual(breakpoint.range, 32)
        XCTAssertEqual(breakpoint.delayedEvents, QueuedBitstream.DelayedEvents(events: [(event: .debugStart, delay: 2)]))
        
        // The second should be for the end control block.
        breakpoint = parsed.breakpoints[1]
        
        XCTAssertGreaterThan(parsed.controlBlocks.count, breakpoint.controlBlockOffset)
        
        XCTAssertEqual(parsed.controlBlocks[breakpoint.controlBlockOffset].destinationAddress, 0)
        dataIndex = parsed.controlBlocks[breakpoint.controlBlockOffset].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed.data[dataIndex], -1)
    }
    
    /// Test that we can call parseBitstream to add entry points for breakpoints in other streams.
    ///
    /// An additional start control block is appended that points to the start of the bitstream.
    func testParseBitstreamTransferringFromBreakpoint() {
        var bitstream1 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream1.append(physicalBits: randomWords[0], count: 32)
        bitstream1.append(physicalBits: randomWords[1], count: 32)

        var parsed1 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream1.wordSize)
        try! parsed1.parseBitstream(bitstream1)

        var bitstream2 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream2.append(physicalBits: randomWords[2], count: 32)
        bitstream2.append(physicalBits: randomWords[3], count: 32)
        
        var parsed2 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream2.wordSize)
        try! parsed2.parseBitstream(bitstream2)
        
        let controlBlocksBase = parsed2.controlBlocks.count
        let dataBase = parsed2.data.count
        
        try! parsed2.parseBitstream(bitstream2, transferringFrom: parsed1.breakpoints[0])
        
        XCTAssertEqual(parsed2.controlBlocks.count, controlBlocksBase + 1)
        XCTAssertEqual(parsed2.data.count, dataBase + 1)

        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase], startControlBlock(dataAt: dataBase, next: 1))
        XCTAssertEqual(parsed2.data[dataBase], 1)
    }
    
    /// Test that we can transfer from a breakpoint that has delayed events pending.
    ///
    /// The transfer-in point should end up with an unrolled copy of itself, to clear the delayed events.
    func testParseBitstreamTransferringFromBreakpointWithDelayedEvents() {
        var bitstream1 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream1.append(physicalBits: randomWords[0], count: 32)
        bitstream1.append(physicalBits: randomWords[1], count: 32)
        bitstream1.append(.debugStart)
        
        var parsed1 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream1.wordSize)
        try! parsed1.parseBitstream(bitstream1)
        
        var bitstream2 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream2.append(physicalBits: randomWords[2], count: 32)
        bitstream2.append(physicalBits: randomWords[3], count: 32)
        
        var parsed2 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream2.wordSize)
        try! parsed2.parseBitstream(bitstream2)
        
        let controlBlocksBase = parsed2.controlBlocks.count
        let dataBase = parsed2.data.count
        
        try! parsed2.parseBitstream(bitstream2, transferringFrom: parsed1.breakpoints[0])
        
        XCTAssertEqual(parsed2.controlBlocks.count, controlBlocksBase + 4)
        XCTAssertEqual(parsed2.data.count, dataBase + 8)
        
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase], startControlBlock(dataAt: dataBase, next: controlBlocksBase + 1))
        XCTAssertEqual(parsed2.data[dataBase], 1)
        
        // The data is directly unrolled without a range change since the range is known to be consistent.
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 1], dataControlBlock(dataAt: dataBase + 1, length: 2, next: controlBlocksBase + 2))
        XCTAssertEqual(parsed2.data[dataBase + 1], randomWords[2])
        XCTAssertEqual(parsed2.data[dataBase + 2], randomWords[3])
        
        // Then the GPIO is cleared,.
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 2], gpioControlBlock(dataAt: dataBase + 3, next: controlBlocksBase + 3))
        XCTAssertEqual(parsed2.data[dataBase + 3], 1 << 19)
        XCTAssertEqual(parsed2.data[dataBase + 4], 0)
        XCTAssertEqual(parsed2.data[dataBase + 5], 0)
        XCTAssertEqual(parsed2.data[dataBase + 6], 0)
        
        // End of the unrolled loop.
        // This can now loop back to the beginning.
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 3], endControlBlock(dataAt: dataBase + 7, next: 1))
        XCTAssertEqual(parsed2.data[dataBase + 7], -1)
    }
    
    /// Test that we can transfer from a breakpoint that has delayed events pending into a stream which ends with the same set.
    ///
    /// Since the same set of delayed events exist at the breakpoint, and at the end of the stream we're transferring into, we can re-use the previous unrolling entirely.
    func testParseBitstreamTransferringFromBreakpointWithSameDelayedEvents() {
        var bitstream1 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream1.append(physicalBits: randomWords[0], count: 32)
        bitstream1.append(physicalBits: randomWords[1], count: 32)
        bitstream1.append(.debugStart)
        
        var parsed1 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream1.wordSize)
        try! parsed1.parseBitstream(bitstream1)
        
        var bitstream2 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream2.append(physicalBits: randomWords[2], count: 32)
        bitstream2.append(physicalBits: randomWords[3], count: 32)
        bitstream2.append(.debugStart)

        var parsed2 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream2.wordSize)
        try! parsed2.parseBitstream(bitstream2)
        
        let controlBlocksBase = parsed2.controlBlocks.count
        let dataBase = parsed2.data.count
        
        try! parsed2.parseBitstream(bitstream2, transferringFrom: parsed1.breakpoints[0])
        
        XCTAssertEqual(parsed2.controlBlocks.count, controlBlocksBase + 1)
        XCTAssertEqual(parsed2.data.count, dataBase + 1)
        
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase], startControlBlock(dataAt: dataBase, next: 5))
        XCTAssertEqual(parsed2.data[dataBase], 1)
    }
    
    /// Test that when transferring from one to another, the range is taken into account.
    ///
    /// Unlike in the usual loop unrolling case, we can't guarantee that the range is consistent at all points in the stream. So if we take the transfer case above, but change the range of the last value, we shouldn't be able to simply re-use the unrolled loop as the range would now be wrong.
    func testParseBitstreamTransferringFromBreakpointWithSameDelayedEventsButDifferentRange() {
        var bitstream1 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream1.append(physicalBits: randomWords[0], count: 32)
        bitstream1.append(physicalBits: randomWords[1], count: 24)
        bitstream1.append(.debugStart)
        
        var parsed1 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream1.wordSize)
        try! parsed1.parseBitstream(bitstream1)
        
        var bitstream2 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream2.append(physicalBits: randomWords[2], count: 32)
        bitstream2.append(physicalBits: randomWords[3], count: 32)
        bitstream2.append(.debugStart)
        
        var parsed2 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream2.wordSize)
        try! parsed2.parseBitstream(bitstream2)
        
        let controlBlocksBase = parsed2.controlBlocks.count
        let dataBase = parsed2.data.count
        
        try! parsed2.parseBitstream(bitstream2, transferringFrom: parsed1.breakpoints[0])
        
        XCTAssertEqual(parsed2.controlBlocks.count, controlBlocksBase + 6)
        XCTAssertEqual(parsed2.data.count, dataBase + 9)
        
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase], startControlBlock(dataAt: dataBase, next: controlBlocksBase + 1))
        XCTAssertEqual(parsed2.data[dataBase], 1)
        
        // The data is unrolled with a range change, since it's not consistent.
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 1], dataControlBlock(dataAt: dataBase + 1, length: 1, next: controlBlocksBase + 2))
        XCTAssertEqual(parsed2.data[dataBase + 1], randomWords[2])
        
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 2], rangeControlBlock(rangeAt: dataBase + 2, next: controlBlocksBase + 3))
        XCTAssertEqual(parsed2.data[dataBase + 2], 32)
        
        // Since there's still a pending GPIO event, and a pending data for it, we can't jump back to the first block; we have to keep unrolling.
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 3], dataControlBlock(dataAt: dataBase + 3, length: 1, next: controlBlocksBase + 4))
        XCTAssertEqual(parsed2.data[dataBase + 3], randomWords[3])
        
        // Then the GPIO is cleared.
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 4], gpioControlBlock(dataAt: dataBase + 4, next: controlBlocksBase + 5))
        XCTAssertEqual(parsed2.data[dataBase + 4], 1 << 19)
        XCTAssertEqual(parsed2.data[dataBase + 5], 0)
        XCTAssertEqual(parsed2.data[dataBase + 6], 0)
        XCTAssertEqual(parsed2.data[dataBase + 7], 0)
        
        // End of the unrolled loop.
        // This can now loop back to the beginning of the unrolled loop (since the event is still pending in our copy).
        XCTAssertEqual(parsed2.controlBlocks[controlBlocksBase + 5], endControlBlock(dataAt: dataBase + 8, next: 5))
        XCTAssertEqual(parsed2.data[dataBase + 8], -1)
    }


    // MARK: Errors
    
    /// Test that an empty bitstream throws an error.
    func testParseEmptyBitstream() {
        let bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        do {
            try parsed.parseBitstream(bitstream)
            XCTFail("Parsing should not have been successful")
        } catch QueuedBitstreamError.containsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown")
        }
    }
    
    /// Test that a bitstream without any data throws an error.
    func testParseBitstreamWithoutData() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.debugStart)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        do {
            try parsed.parseBitstream(bitstream)
            XCTFail("Parsing should not have been successful")
        } catch QueuedBitstreamError.containsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown")
        }
    }
    
    /// Test that a bitstream with nothing following a repeating section start throws an error.
    func testParseBitstreamWithEmptyRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        do {
            try parsed.parseBitstream(bitstream)
            XCTFail("Parsing should not have been successful")
        } catch QueuedBitstreamError.containsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }
    
    /// Test that a bitstream with no data following a repeating section start throws an error.
    func testParseBitstreamWithoutDataInRepeatingSection() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        bitstream.append(.loopStart)
        bitstream.append(.debugStart)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        do {
            try parsed.parseBitstream(bitstream)
            XCTFail("Parsing should not have been successful")
        } catch QueuedBitstreamError.containsNoData {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }
    
    /// Test that a bitstream with nothing prior to a breakpoint throws an error.
    func testParseBitstreamWithNothingBeforeBreakpoint() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.breakpoint)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)

        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        do {
            try parsed.parseBitstream(bitstream)
            XCTFail("Parsing should not have been successful")
        } catch QueuedBitstreamError.breakpointAtStart {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }
    
    /// Test that a bitstream with no data prior to a breakpoint throws an error.
    func testParseBitstreamWithoutDataBeforeBreakpoint() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(.debugStart)
        bitstream.append(.breakpoint)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        bitstream.append(physicalBits: randomWords[1], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        do {
            try parsed.parseBitstream(bitstream)
            XCTFail("Parsing should not have been successful")
        } catch QueuedBitstreamError.breakpointAtStart {
            // Pass
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    
    // MARK: Functional tests
    
    /// Test with an operations mode packet.
    func testParseBitstreamOperationsMode() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(operationsModePacket: .speed28Step(address: 3, direction: .forward, speed: 14))
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 15)
        XCTAssertEqual(parsed.data.count, 45)
        
        XCTAssertEqual(parsed.data[0], 0)
        
        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], Int(bitPattern: 0b11110000111100001111000011110000))
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 13, next: 4))
        XCTAssertEqual(parsed.data[4],  Int(bitPattern: 0b11110000111100001111000011110000))
        XCTAssertEqual(parsed.data[5],  Int(bitPattern: 0b11110000111100001111000011110000))
        XCTAssertEqual(parsed.data[6],  Int(bitPattern: 0b11110000111100001111111000000011))
        XCTAssertEqual(parsed.data[7],  Int(bitPattern: 0b11111000000011111110000000111111))
        XCTAssertEqual(parsed.data[8],  Int(bitPattern: 0b10000000111111100000001111111000))
        XCTAssertEqual(parsed.data[9],  Int(bitPattern: 0b00001111111000000011110000111100))
        XCTAssertEqual(parsed.data[10], Int(bitPattern: 0b00111111100000001111111000000011))
        XCTAssertEqual(parsed.data[11], Int(bitPattern: 0b11000011110000111100001111000011))
        XCTAssertEqual(parsed.data[12], Int(bitPattern: 0b11111000000011111110000000111111))
        XCTAssertEqual(parsed.data[13], Int(bitPattern: 0b10000000111111100000001111111000))
        XCTAssertEqual(parsed.data[14], Int(bitPattern: 0b00001111000011110000111100001111))
        XCTAssertEqual(parsed.data[15], Int(bitPattern: 0b00001111111000000011110000111100))
        XCTAssertEqual(parsed.data[16], Int(bitPattern: 0b001111000011) << 20)
        
        XCTAssertEqual(parsed.controlBlocks[4], rangeControlBlock(rangeAt: 17, next: 5))
        XCTAssertEqual(parsed.data[17], 12)
        
        // Delayed RailCom Cutout start aligned here.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 18, length: 1, next: 6))
        XCTAssertEqual(parsed.data[18], Int(bitPattern: 0b110000111100001111000011110000) << 2) // 30
        
        XCTAssertEqual(parsed.controlBlocks[6], rangeControlBlock(rangeAt: 19, next: 7))
        XCTAssertEqual(parsed.data[19], 30)
        
        // End of first loop.
        // Delayed RailCom Cutout end aligned here.
        XCTAssertEqual(parsed.controlBlocks[7], endControlBlock(dataAt: 20, next: 8))
        XCTAssertEqual(parsed.data[20], -1)
        
        // Unroll of loop begins here.
        // The first data item is enough to end the delayed RailCom cutout start, so and also needs a range.
        XCTAssertEqual(parsed.controlBlocks[8], dataControlBlock(dataAt: 21, length: 1, next: 9))
        XCTAssertEqual(parsed.data[21], Int(bitPattern: 0b11110000111100001111000011110000))
        
        XCTAssertEqual(parsed.controlBlocks[9], rangeControlBlock(rangeAt: 22, next: 10))
        XCTAssertEqual(parsed.data[22], 32)
        
        XCTAssertEqual(parsed.controlBlocks[10], gpioControlBlock(dataAt: 23, next: 11))
        XCTAssertEqual(parsed.data[23], 0)
        XCTAssertEqual(parsed.data[24], 0)
        XCTAssertEqual(parsed.data[25], 1 << 17)
        XCTAssertEqual(parsed.data[26], 0)
        
        // One more data is enough to end the delayed RailCom cutout end.
        XCTAssertEqual(parsed.controlBlocks[11], dataControlBlock(dataAt: 27, length: 1, next: 12))
        XCTAssertEqual(parsed.data[27], Int(bitPattern: 0b11110000111100001111000011110000))
        
        XCTAssertEqual(parsed.controlBlocks[12], gpioControlBlock(dataAt: 28, next: 13))
        XCTAssertEqual(parsed.data[28], 1 << 17)
        XCTAssertEqual(parsed.data[29], 0)
        XCTAssertEqual(parsed.data[30], 0)
        XCTAssertEqual(parsed.data[31], 0)
        
        // We now have to keep unrolling forwards until we reach the first data that we can loop to, which is where we broke for the RailCom Cutout start.
        XCTAssertEqual(parsed.controlBlocks[13], dataControlBlock(dataAt: 32, length: 12, next: 14))
        XCTAssertEqual(parsed.data[32], Int(bitPattern: 0b11110000111100001111000011110000))
        XCTAssertEqual(parsed.data[33], Int(bitPattern: 0b11110000111100001111111000000011))
        XCTAssertEqual(parsed.data[34], Int(bitPattern: 0b11111000000011111110000000111111))
        XCTAssertEqual(parsed.data[35], Int(bitPattern: 0b10000000111111100000001111111000))
        XCTAssertEqual(parsed.data[36], Int(bitPattern: 0b00001111111000000011110000111100))
        XCTAssertEqual(parsed.data[37], Int(bitPattern: 0b00111111100000001111111000000011))
        XCTAssertEqual(parsed.data[38], Int(bitPattern: 0b11000011110000111100001111000011))
        XCTAssertEqual(parsed.data[39], Int(bitPattern: 0b11111000000011111110000000111111))
        XCTAssertEqual(parsed.data[40], Int(bitPattern: 0b10000000111111100000001111111000))
        XCTAssertEqual(parsed.data[41], Int(bitPattern: 0b00001111000011110000111100001111))
        XCTAssertEqual(parsed.data[42], Int(bitPattern: 0b00001111111000000011110000111100))
        XCTAssertEqual(parsed.data[43], Int(bitPattern: 0b001111000011) << 20)
        
        XCTAssertEqual(parsed.controlBlocks[14], rangeControlBlock(rangeAt: 44, next: 5))
        XCTAssertEqual(parsed.data[44], 12)
    }
    
    /// Test with an operations mode packet marked for debugging.
    func testParseBitstreamOperationsModeWithDebug() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(operationsModePacket: .speed28Step(address: 3, direction: .forward, speed: 14), debug: true)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        
        XCTAssertEqual(parsed.controlBlocks.count, 21)
        XCTAssertEqual(parsed.data.count, 41)
        
        XCTAssertEqual(parsed.data[0], 0)
        
        XCTAssertEqual(parsed.controlBlocks[0], startControlBlock(dataAt: 1, next: 1))
        XCTAssertEqual(parsed.data[1], 1)
        
        XCTAssertEqual(parsed.controlBlocks[1], dataControlBlock(dataAt: 2, length: 1, next: 2))
        XCTAssertEqual(parsed.data[2], Int(bitPattern: 0b11110000111100001111000011110000))
        
        XCTAssertEqual(parsed.controlBlocks[2], rangeControlBlock(rangeAt: 3, next: 3))
        XCTAssertEqual(parsed.data[3], 32)
        
        XCTAssertEqual(parsed.controlBlocks[3], dataControlBlock(dataAt: 4, length: 3, next: 4))
        XCTAssertEqual(parsed.data[4], Int(bitPattern: 0b11110000111100001111000011110000))
        XCTAssertEqual(parsed.data[5], Int(bitPattern: 0b11110000111100001111000011110000))
        XCTAssertEqual(parsed.data[6], Int(bitPattern: 0b1111000011110000) << 16)
        
        XCTAssertEqual(parsed.controlBlocks[4], rangeControlBlock(rangeAt: 7, next: 5))
        XCTAssertEqual(parsed.data[7], 16)
        
        // Delayed Debug start aligned here.
        XCTAssertEqual(parsed.controlBlocks[5], dataControlBlock(dataAt: 8, length: 1, next: 6))
        XCTAssertEqual(parsed.data[8], Int(bitPattern: 0b11111110000000111111100000001111))
        
        XCTAssertEqual(parsed.controlBlocks[6], rangeControlBlock(rangeAt: 9, next: 7))
        XCTAssertEqual(parsed.data[9], 32)
        
        XCTAssertEqual(parsed.controlBlocks[7], dataControlBlock(dataAt: 10, length: 1, next: 8))
        XCTAssertEqual(parsed.data[10], Int(bitPattern: 0b11100000001111111000000011111110))
        
        XCTAssertEqual(parsed.controlBlocks[8], gpioControlBlock(dataAt: 11, next: 9))
        XCTAssertEqual(parsed.data[11], 1 << 19)
        XCTAssertEqual(parsed.data[12], 0)
        XCTAssertEqual(parsed.data[13], 0)
        XCTAssertEqual(parsed.data[14], 0)
        
        XCTAssertEqual(parsed.controlBlocks[9], dataControlBlock(dataAt: 15, length: 8, next: 10))
        XCTAssertEqual(parsed.data[15], Int(bitPattern: 0b00000011111110000000111111100000))
        XCTAssertEqual(parsed.data[16], Int(bitPattern: 0b00111100001111000011111110000000))
        XCTAssertEqual(parsed.data[17], Int(bitPattern: 0b11111110000000111100001111000011))
        XCTAssertEqual(parsed.data[18], Int(bitPattern: 0b11000011110000111111100000001111))
        XCTAssertEqual(parsed.data[19], Int(bitPattern: 0b11100000001111111000000011111110))
        XCTAssertEqual(parsed.data[20], Int(bitPattern: 0b00000011111110000000111100001111))
        XCTAssertEqual(parsed.data[21], Int(bitPattern: 0b00001111000011110000111111100000))
        XCTAssertEqual(parsed.data[22], Int(bitPattern: 0b0011110000111100001111000011) << 4)
        
        XCTAssertEqual(parsed.controlBlocks[10], rangeControlBlock(rangeAt: 23, next: 11))
        XCTAssertEqual(parsed.data[23], 28)
        
        // Delayed RailCom Cutout start aligned here.
        XCTAssertEqual(parsed.controlBlocks[11], dataControlBlock(dataAt: 24, length: 1, next: 12))
        XCTAssertEqual(parsed.data[24], Int(bitPattern: 0b110000111100001111000011110000) << 2)
        
        XCTAssertEqual(parsed.controlBlocks[12], rangeControlBlock(rangeAt: 25, next: 13))
        XCTAssertEqual(parsed.data[25], 30)
        
        // End of first loop.
        // Delayed RailCom Cutout end, and Debug end, aligned here.
        XCTAssertEqual(parsed.controlBlocks[13], endControlBlock(dataAt: 26, next: 14))
        XCTAssertEqual(parsed.data[26], -1)
        
        // Unroll of loop begins here.
        // The first data item is enough to end the delayed RailCom cutout start, so and also needs a range.
        XCTAssertEqual(parsed.controlBlocks[14], dataControlBlock(dataAt: 27, length: 1, next: 15))
        XCTAssertEqual(parsed.data[27], Int(bitPattern: 0b11110000111100001111000011110000))
        
        XCTAssertEqual(parsed.controlBlocks[15], rangeControlBlock(rangeAt: 28, next: 16))
        XCTAssertEqual(parsed.data[28], 32)
        
        XCTAssertEqual(parsed.controlBlocks[16], gpioControlBlock(dataAt: 29, next: 17))
        XCTAssertEqual(parsed.data[29], 0)
        XCTAssertEqual(parsed.data[30], 0)
        XCTAssertEqual(parsed.data[31], 1 << 17)
        XCTAssertEqual(parsed.data[32], 0)
        
        // One more data is enough to end the delayed RailCom cutout end, and Debug end.
        XCTAssertEqual(parsed.controlBlocks[17], dataControlBlock(dataAt: 33, length: 1, next: 18))
        XCTAssertEqual(parsed.data[33], Int(bitPattern: 0b11110000111100001111000011110000))
        
        XCTAssertEqual(parsed.controlBlocks[18], gpioControlBlock(dataAt: 34, next: 19))
        XCTAssertEqual(parsed.data[34], 1 << 17)
        XCTAssertEqual(parsed.data[35], 0)
        XCTAssertEqual(parsed.data[36], 1 << 19)
        XCTAssertEqual(parsed.data[37], 0)
        
        // We now have to keep unrolling forwards until we reach the first data that we can loop to, which is where we broke for the Debug start.
        XCTAssertEqual(parsed.controlBlocks[19], dataControlBlock(dataAt: 38, length: 2, next: 20))
        XCTAssertEqual(parsed.data[38], Int(bitPattern: 0b11110000111100001111000011110000))
        XCTAssertEqual(parsed.data[39], Int(bitPattern: 0b1111000011110000) << 16)
        
        XCTAssertEqual(parsed.controlBlocks[20], rangeControlBlock(rangeAt: 40, next: 5))
        XCTAssertEqual(parsed.data[40], 16)
    }
    
    
    // MARK: Commit
    
    /// Test that we can commit a parsed bitstream to uncached memory.
    ///
    /// The control blocks and data of the parsed bitstream should be concatenated into the allocated memory region.
    func testCommitConcatenates() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        try! parsed.commit()
        
        XCTAssertNotNil(parsed.memory)
        
        var bytes = parsed.memory!.pointer
        
        for controlBlock in parsed.controlBlocks {
            let committedControlBlock = bytes.load(as: DMAControlBlock.self)
            XCTAssertEqual(committedControlBlock, controlBlock)
            
            bytes = bytes.advanced(by: MemoryLayout<DMAControlBlock>.stride)
        }
        
        for data in parsed.data {
            let committedData = bytes.load(as: Int.self)
            XCTAssertEqual(committedData, data)
            
            bytes = bytes.advanced(by: MemoryLayout<Int>.stride)
        }
    }
    
    /// Test that the address values are modified during commit.
    ///
    /// Committing the bitstream modifies the source and destination addresses to point within the data block of the returned memory region, and the next control block address to point within the control blocks in the returned memory region.
    ///
    /// Make sure the destination address in the data and range control blocks aren't modified, since those are within the peripheral address space.
    func testCommitModifiesAddresses() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        let oldControlBlocks = parsed.controlBlocks
        let dataOffset = MemoryLayout<DMAControlBlock>.stride * oldControlBlocks.count
        
        try! parsed.commit()
        
        XCTAssertNotNil(parsed.memory)
        let busAddress = parsed.memory!.busAddress
        
        XCTAssertEqual(parsed.controlBlocks.count, oldControlBlocks.count)
        
        // Start.
        XCTAssertEqual(parsed.controlBlocks[0].sourceAddress, busAddress + dataOffset + oldControlBlocks[0].sourceAddress)
        XCTAssertEqual(parsed.controlBlocks[0].destinationAddress, busAddress + dataOffset + oldControlBlocks[0].destinationAddress)
        XCTAssertEqual(parsed.controlBlocks[0].nextControlBlockAddress, busAddress + oldControlBlocks[0].nextControlBlockAddress)
        
        // Data.
        XCTAssertEqual(parsed.controlBlocks[1].sourceAddress, busAddress + dataOffset + oldControlBlocks[1].sourceAddress)
        XCTAssertEqual(parsed.controlBlocks[1].destinationAddress, oldControlBlocks[1].destinationAddress)
        XCTAssertEqual(parsed.controlBlocks[1].nextControlBlockAddress, busAddress + oldControlBlocks[1].nextControlBlockAddress)
        
        // Range.
        XCTAssertEqual(parsed.controlBlocks[2].sourceAddress, busAddress + dataOffset + oldControlBlocks[2].sourceAddress)
        XCTAssertEqual(parsed.controlBlocks[2].destinationAddress, oldControlBlocks[2].destinationAddress)
        XCTAssertEqual(parsed.controlBlocks[2].nextControlBlockAddress, busAddress + oldControlBlocks[2].nextControlBlockAddress)
        
        // End.
        XCTAssertEqual(parsed.controlBlocks[3].sourceAddress, busAddress + dataOffset + oldControlBlocks[3].sourceAddress)
        XCTAssertEqual(parsed.controlBlocks[3].destinationAddress, busAddress + dataOffset + oldControlBlocks[3].destinationAddress)
        XCTAssertEqual(parsed.controlBlocks[3].nextControlBlockAddress, busAddress + oldControlBlocks[3].nextControlBlockAddress)
    }
    
    /// Test that the data values are not modified during commit.
    func testCommitDoesNotModifyData() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        let oldData = parsed.data
        
        try! parsed.commit()
        
        XCTAssertNotNil(parsed.memory)
        
        XCTAssertEqual(parsed.data, oldData)
    }
    
    /// Test that commit() works when the end control block address is the stop address.
    func testCommitWithStopAddress() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream, repeating: false)
        let oldControlBlocks = parsed.controlBlocks
        
        try! parsed.commit()
        
        XCTAssertNotNil(parsed.memory)
        
        XCTAssertEqual(parsed.controlBlocks.count, oldControlBlocks.count)
        XCTAssertEqual(parsed.controlBlocks[3].nextControlBlockAddress, DMAControlBlock.stopAddress)
    }
    
    
    // MARK: Post-commit details.
    
    /// Test that the bus address of the memory region is copied into the queued bitstream structure.
    func testBusAddress() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        try! parsed.commit()
        
        XCTAssertNotNil(parsed.memory)
        XCTAssertEqual(parsed.busAddress, parsed.memory!.busAddress)
    }
    
    /// Test that isTransmitting has the right value at the different stages.
    func testIsTransmitting() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        try! parsed.commit()
        
        XCTAssertFalse(parsed.isTransmitting)
        
        let dataOffset = MemoryLayout<DMAControlBlock>.stride * parsed.controlBlocks.count
        let data = parsed.memory!.pointer.advanced(by: dataOffset).assumingMemoryBound(to: Int.self)
        
        // Make sure it goes true after the start control block.
        data[0] = data[1]
        
        XCTAssertTrue(parsed.isTransmitting)
        
        // And remains true after the end control block.
        data[0] = data[parsed.data.count - 1]
        
        XCTAssertTrue(parsed.isTransmitting)
    }
    
    /// Test that isRepeating has the right value at the different stages.
    func testIsRepeating() {
        var bitstream = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream.append(physicalBits: randomWords[0], count: 32)
        
        var parsed = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream.wordSize)
        try! parsed.parseBitstream(bitstream)
        try! parsed.commit()
        
        XCTAssertFalse(parsed.isRepeating)
        
        let dataOffset = MemoryLayout<DMAControlBlock>.stride * parsed.controlBlocks.count
        let data = parsed.memory!.pointer.advanced(by: dataOffset).assumingMemoryBound(to: Int.self)
        
        // Make sure it remains false after the start control block.
        data[0] = data[1]
        
        XCTAssertFalse(parsed.isRepeating)
        
        // And goes true after the end control block.
        data[0] = data[parsed.data.count - 1]
        
        XCTAssertTrue(parsed.isRepeating)
    }
    
    
    // MARK: Transferring
    
    /// Test that we can generate a queued bitstream from a bitstream, when transferring from another.
    ///
    /// Since parseBitstream is already tested, just make sure a list of transfer offsets is returned and matches the number of breakpoints, and that each is a start control block.
    func testTransferFromInto() {
        var bitstream1 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream1.append(physicalBits: randomWords[0], count: 32)
        bitstream1.append(.breakpoint)
        bitstream1.append(physicalBits: randomWords[1], count: 32)

        var parsed1 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream1.wordSize)
        try! parsed1.parseBitstream(bitstream1)
        try! parsed1.commit()
        
        var bitstream2 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream2.append(physicalBits: randomWords[2], count: 32)
        bitstream2.append(physicalBits: randomWords[3], count: 32)

        var parsed2 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream2.wordSize)
        let transferOffsets = try! parsed2.transfer(from: parsed1, into: bitstream2)
        
        XCTAssertEqual(transferOffsets.count, 2)
        
        XCTAssertGreaterThan(parsed2.controlBlocks.count, transferOffsets[0])
        XCTAssertEqual(parsed2.controlBlocks[transferOffsets[0]].destinationAddress, 0)
        var dataIndex = parsed2.controlBlocks[transferOffsets[0]].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed2.data[dataIndex], 1)

        XCTAssertGreaterThan(parsed2.controlBlocks.count, transferOffsets[1])
        XCTAssertEqual(parsed2.controlBlocks[transferOffsets[1]].destinationAddress, 0)
        dataIndex = parsed2.controlBlocks[transferOffsets[1]].sourceAddress / MemoryLayout<Int>.stride
        XCTAssertEqual(parsed2.data[dataIndex], 1)
    }
    
    /// Test that we can transfer from one queued bitstream to another before it's repeating.
    ///
    /// Only the end control block breakpoint should be changed.
    func testTransferToAtBeforeRepeating() {
        var bitstream1 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream1.append(physicalBits: randomWords[0], count: 32)
        bitstream1.append(.breakpoint)
        bitstream1.append(physicalBits: randomWords[1], count: 32)
        
        var parsed1 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream1.wordSize)
        try! parsed1.parseBitstream(bitstream1)
        try! parsed1.commit()
        
        var bitstream2 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream2.append(physicalBits: randomWords[2], count: 32)
        bitstream2.append(physicalBits: randomWords[3], count: 32)
        
        var parsed2 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream2.wordSize)
        let transferOffsets = try! parsed2.transfer(from: parsed1, into: bitstream2)

        try! parsed2.commit()
        parsed1.transfer(to: parsed2, at: transferOffsets)
        
        let uncachedControlBlocks = parsed1.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)

        // The nextControlBlockAddress of the first breakpoint (data/range) should not be changed.
        XCTAssertNotEqual(uncachedControlBlocks[parsed1.breakpoints[0].controlBlockOffset].nextControlBlockAddress, parsed2.busAddress + MemoryLayout<DMAControlBlock>.stride * transferOffsets[0])
        
        // The nextControlBlockAddress of the second breakpoint (end control block) should be changed.
        XCTAssertEqual(uncachedControlBlocks[parsed1.breakpoints[1].controlBlockOffset].nextControlBlockAddress, parsed2.busAddress + MemoryLayout<DMAControlBlock>.stride * transferOffsets[1])
    }
    
    /// Test that we can transfer from one queued bitstream to another after it's repeating.
    ///
    /// Both breakpoints should be changed.
    func testTransferToAtAfterRepeating() {
        var bitstream1 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream1.append(physicalBits: randomWords[0], count: 32)
        bitstream1.append(.breakpoint)
        bitstream1.append(physicalBits: randomWords[1], count: 32)
        
        var parsed1 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream1.wordSize)
        try! parsed1.parseBitstream(bitstream1)
        try! parsed1.commit()
        
        var bitstream2 = Bitstream(bitDuration: 14.5, wordSize: 32)
        bitstream2.append(physicalBits: randomWords[2], count: 32)
        bitstream2.append(physicalBits: randomWords[3], count: 32)
        
        var parsed2 = QueuedBitstream(raspberryPi: raspberryPi, wordSize: bitstream2.wordSize)
        let transferOffsets = try! parsed2.transfer(from: parsed1, into: bitstream2)
        
        try! parsed2.commit()
        
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * parsed1.controlBlocks.count
        let uncachedData = parsed1.memory!.pointer.advanced(by: controlBlocksSize).assumingMemoryBound(to: Int.self)
        
        // Mark the queued bitstream as repeating before we do the transfer.
        uncachedData[0] = -1
        
        parsed1.transfer(to: parsed2, at: transferOffsets)

        let uncachedControlBlocks = parsed1.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        // The nextControlBlockAddress of both breakpoints should be changed.
        XCTAssertEqual(uncachedControlBlocks[parsed1.breakpoints[0].controlBlockOffset].nextControlBlockAddress, parsed2.busAddress + MemoryLayout<DMAControlBlock>.stride * transferOffsets[0])
        XCTAssertEqual(uncachedControlBlocks[parsed1.breakpoints[1].controlBlockOffset].nextControlBlockAddress, parsed2.busAddress + MemoryLayout<DMAControlBlock>.stride * transferOffsets[1])
    }

}

extension QueuedBitstreamTests {
    
    static var allTests = {
        return [
            ("testParseBitstreamSingleWord", testParseBitstreamSingleWord),
            ("testParseBitstreamSecondWordSameSize", testParseBitstreamSecondWordSameSize),
            ("testParseBitstreamSecondWordDifferentSize", testParseBitstreamSecondWordDifferentSize),
            ("testParseBitstreamThirdWordSameSize", testParseBitstreamThirdWordSameSize),
            ("testParseBitstreamThirdWordDifferentSize", testParseBitstreamThirdWordDifferentSize),
            
            ("testParseBitstreamReturnValue", testParseBitstreamReturnValue),
            ("testParseBitstreamSecondCallReturnValue", testParseBitstreamSecondCallReturnValue),
            
            ("testParseBitstreamGPIOEvent", testParseBitstreamGPIOEvent),
            ("testParseBitstreamMultipleGPIOSetEvent", testParseBitstreamMultipleGPIOSetEvent),
            ("testParseBitstreamMultipleGPIOClearEvent", testParseBitstreamMultipleGPIOClearEvent),
            ("testParseBitstreamMultipleGPIOEvent", testParseBitstreamMultipleGPIOEvent),
            ("testParseBitstreamMultipleGPIOLastWins", testParseBitstreamMultipleGPIOLastWins),
            ("testParseBitstreamGPIOEventBreaksData", testParseBitstreamGPIOEventBreaksData),
            
            ("testParseBitstreamGPIOEventUnrollsLoop", testParseBitstreamGPIOEventUnrollsLoop),
            ("testParseBitstreamGPIOEventUnrollsLoopAcrossOtherGPIOEvent", testParseBitstreamGPIOEventUnrollsLoopAcrossOtherGPIOEvent),
            ("testParseBitstreamGPIOEventAtEndUnrollsLoop", testParseBitstreamGPIOEventAtEndUnrollsLoop),
            ("testParseBitstreamGPIOEventUnrollsLoopTwice", testParseBitstreamGPIOEventUnrollsLoopTwice),
            ("testParseBitstreamGPIOEventUnrollsLoopTwiceNotToStart", testParseBitstreamGPIOEventUnrollsLoopTwiceNotToStart),
            ("testParseBitstreamGPIOEventUnrollsLoopRepeatingData", testParseBitstreamGPIOEventUnrollsLoopRepeatingData),
            ("testParseBitstreamRepeating", testParseBitstreamRepeating),
            ("testParseBitstreamRepeatingDoesntUnroll", testParseBitstreamRepeatingDoesntUnroll),
        
            ("testParseBitstreamWithRepeatingSection", testParseBitstreamWithRepeatingSection),
            ("testParseBitstreamGPIOEventUnrollsToRepeatingSection", testParseBitstreamGPIOEventUnrollsToRepeatingSection),
            ("testParseBitstreamGPIOEventUnrollsWhenAcrossRepeatingSection", testParseBitstreamGPIOEventUnrollsWhenAcrossRepeatingSection),
            
            ("testParseBitstreamWithBreakpointAtEnd", testParseBitstreamWithBreakpointAtEnd),
            ("testParseBitstreamWithBreakpointAtEndAfterRange", testParseBitstreamWithBreakpointAtEndAfterRange),
            ("testParseBitstreamWithBreakpointAtEndAfterDelayedEvents", testParseBitstreamWithBreakpointAtEndAfterDelayedEvents),
            ("testParseBitstreamWithBreakpointAtMultipleEndsAfterDelayedEvents", testParseBitstreamWithBreakpointAtMultipleEndsAfterDelayedEvents),
            ("testParseBitstreamWithBreakpoint", testParseBitstreamWithBreakpoint),
            ("testParseBitstreamWithBreakpointAfterRange", testParseBitstreamWithBreakpointAfterRange),
            ("testParseBitstreamWithBreakpointAfterDelayedEvent", testParseBitstreamWithBreakpointAfterDelayedEvent),
            ("testParseBitstreamTransferringFromBreakpoint", testParseBitstreamTransferringFromBreakpoint),
            ("testParseBitstreamTransferringFromBreakpointWithDelayedEvents", testParseBitstreamTransferringFromBreakpointWithDelayedEvents),
            ("testParseBitstreamTransferringFromBreakpointWithSameDelayedEvents", testParseBitstreamTransferringFromBreakpointWithSameDelayedEvents),
            ("testParseBitstreamTransferringFromBreakpointWithSameDelayedEventsButDifferentRange", testParseBitstreamTransferringFromBreakpointWithSameDelayedEventsButDifferentRange),
            
            ("testParseEmptyBitstream", testParseEmptyBitstream),
            ("testParseBitstreamWithoutData", testParseBitstreamWithoutData),
            ("testParseBitstreamWithEmptyRepeatingSection", testParseBitstreamWithEmptyRepeatingSection),
            ("testParseBitstreamWithoutDataInRepeatingSection", testParseBitstreamWithoutDataInRepeatingSection),
            ("testParseBitstreamWithNothingBeforeBreakpoint", testParseBitstreamWithNothingBeforeBreakpoint),
            ("testParseBitstreamWithoutDataBeforeBreakpoint", testParseBitstreamWithoutDataBeforeBreakpoint),
            
            ("testParseBitstreamOperationsMode", testParseBitstreamOperationsMode),
            ("testParseBitstreamOperationsModeWithDebug", testParseBitstreamOperationsModeWithDebug),
            
            ("testCommitConcatenates", testCommitConcatenates),
            ("testCommitModifiesAddresses", testCommitModifiesAddresses),
            ("testCommitDoesNotModifyData", testCommitDoesNotModifyData),
            ("testCommitWithStopAddress", testCommitWithStopAddress),
            
            ("testBusAddress", testBusAddress),
            ("testIsTransmitting", testIsTransmitting),
            ("testIsRepeating", testIsRepeating),
            
            ("testTransferFromInto", testTransferFromInto),
            ("testTransferToAtBeforeRepeating", testTransferToAtBeforeRepeating),
            ("testTransferToAtAfterRepeating", testTransferToAtAfterRepeating),
            ]
    }()
    
}
