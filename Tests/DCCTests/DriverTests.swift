//
//  DriverTests.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import XCTest

import Foundation
import Dispatch

@testable import RaspberryPi
@testable import DCC


class DriverTests : XCTestCase {

    var raspberryPi: RaspberryPi!
    
    override func setUp() {
        super.setUp()
        
        raspberryPi = TestRaspberryPi(peripheralAddress: 0x3f000000, peripheralSize: 0x01000000)
    }
    
    func markTransmitting(_ queuedBitstream: QueuedBitstream) {
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * queuedBitstream.controlBlocks.count
        let uncachedData = queuedBitstream.memory!.pointer.advanced(by: controlBlocksSize).assumingMemoryBound(to: Int.self)

        uncachedData[0] = 1
    }
    
    func markRepeating(_ queuedBitstream: QueuedBitstream) {
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * queuedBitstream.controlBlocks.count
        let uncachedData = queuedBitstream.memory!.pointer.advanced(by: controlBlocksSize).assumingMemoryBound(to: Int.self)
        
        uncachedData[0] = -1
    }
    
    
    // MARK: Queue testing.
    
    /// Test that when we queue the first bitstream, a start bitstream is added as well, and the DMA activated and pointed to that.
    func testQueueStartBitstream() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream)
        
        // There should be two queued bitstreams; the first is the startup bitstream which should transfer to the second, and the second is the bitstream we actually sent that should repeat itself.
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        
        let startBitstream = driver.bitstreamQueue[0]
        let queuedBitstream = driver.bitstreamQueue[1]

        // Make sure the startup bitstream points to the queued bitstream.
        var controlBlocks = startBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        XCTAssertEqual(startBitstream.breakpoints.count, 1)
        XCTAssertEqual(controlBlocks[startBitstream.breakpoints[0].controlBlockOffset].nextControlBlockAddress, queuedBitstream.busAddress)
        
        // Make sure the queued bitstream loops back to itself.
        controlBlocks = queuedBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * queuedBitstream.controlBlocks.count
        
        XCTAssertGreaterThanOrEqual(queuedBitstream.breakpoints.count, 1)
        for breakpoint in queuedBitstream.breakpoints {
            let nextControlBlockAddress = controlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress
            XCTAssertGreaterThanOrEqual(nextControlBlockAddress, queuedBitstream.busAddress)
            XCTAssertLessThan(nextControlBlockAddress, queuedBitstream.busAddress + controlBlocksSize)
        }

        // Make sure that DMA is active and points to the start bitstream.
        let dma = raspberryPi.dma(channel: Driver.dmaChannel)
        XCTAssertEqual(dma.controlBlockAddress, startBitstream.busAddress)
        XCTAssertTrue(dma.controlStatus.contains(.active))
        
        driver.isRunning = false
    }
    
    /// Test that the completion handler is run once the bitstream is marked as repeating.
    func testQueueCompletionHandler() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        // The completion handler is asynchronous after the completion, so use a semaphore to wait for it.
        var completionHandlerRun = false
        let completionSemaphore = DispatchSemaphore(value: 0)
        try! driver.queue(bitstream: bitstream) {
            completionHandlerRun = true
            completionSemaphore.signal()
        }
        
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        XCTAssertFalse(completionHandlerRun)

        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        XCTAssertEqual(driver.dispatchGroup.wait(timeout: .now() + .seconds(1)), .success)
        XCTAssertEqual(completionSemaphore.wait(timeout: .now() + .seconds(1)), .success)
        
        XCTAssertTrue(completionHandlerRun)
        
        driver.isRunning = false
    }
    
    /// Test that we can queue a bitstream while the previous bitstream is still transmitting and not yet repeating.
    ///
    /// Only the end breakpoint should get set.
    func testQueueWhileTransmitting() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream1 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        bitstream1.append(.breakpoint)
        bitstream1.append(physicalBits: Int(bitPattern: 0xb000b1e5), count: 32)

        try! driver.queue(bitstream: bitstream1)
        
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(driver.bitstreamQueue[1])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }

        XCTAssertEqual(driver.bitstreamQueue.count, 1)

        var bitstream2 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0xcafebabe), count: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0x99c0ffee), count: 32)

        try! driver.queue(bitstream: bitstream2)

        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        
        let previousBitstream = driver.bitstreamQueue[0]
        let queuedBitstream = driver.bitstreamQueue[1]
        
        // Make sure only the end control block points to the new bitstream.
        let controlBlocks = previousBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        XCTAssertGreaterThanOrEqual(previousBitstream.breakpoints.count, 2)
        
        // First breakpoint should be still within the previous bitstream.
        XCTAssertGreaterThanOrEqual(controlBlocks[previousBitstream.breakpoints[0].controlBlockOffset].nextControlBlockAddress, previousBitstream.busAddress)
        XCTAssertLessThan(controlBlocks[previousBitstream.breakpoints[0].controlBlockOffset].nextControlBlockAddress, previousBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * previousBitstream.controlBlocks.count)

        // Second breakpoint should be within the next bitstream.
        XCTAssertGreaterThanOrEqual(controlBlocks[previousBitstream.breakpoints[1].controlBlockOffset].nextControlBlockAddress, queuedBitstream.busAddress)
        XCTAssertLessThan(controlBlocks[previousBitstream.breakpoints[1].controlBlockOffset].nextControlBlockAddress, queuedBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * queuedBitstream.controlBlocks.count)

        driver.isRunning = false
    }

    /// Test that we can queue a bitstream while the previous bitstream is repeating.
    ///
    /// All of the breakpoints should get changed.
    func testQueueWhileRepeating() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream1 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        bitstream1.append(.breakpoint)
        bitstream1.append(physicalBits: Int(bitPattern: 0xb000b1e5), count: 32)
        
        try! driver.queue(bitstream: bitstream1)
        
        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        XCTAssertEqual(driver.dispatchGroup.wait(timeout: .now() + .seconds(1)), .success)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        
        var bitstream2 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0xcafebabe), count: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0x99c0ffee), count: 32)
        
        try! driver.queue(bitstream: bitstream2)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        
        let previousBitstream = driver.bitstreamQueue[0]
        let queuedBitstream = driver.bitstreamQueue[1]
        
        // Make sure both control block points to the new bitstream.
        let controlBlocks = previousBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        XCTAssertGreaterThanOrEqual(previousBitstream.breakpoints.count, 2)
        
        for breakpoint in previousBitstream.breakpoints {
            let nextControlBlockAddress = controlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress
            XCTAssertGreaterThanOrEqual(nextControlBlockAddress, queuedBitstream.busAddress)
            XCTAssertLessThan(nextControlBlockAddress, queuedBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * queuedBitstream.controlBlocks.count)
        }

        driver.isRunning = false
    }

    /// Test that the start bitstream is freed once the queued bitstream is transmitting.
    func testQueueRemovesStartOnFirstTransmitting() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        
        weak var startupMemory = driver.bitstreamQueue[0].memory
        let queuedBitstream = driver.bitstreamQueue[1]
        
        // Mark the start bitstream repeating, and the queued bitstream as transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(queuedBitstream)
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        // The startup bitstream should have been removed from the queue and its memory freed.
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        XCTAssertEqual(driver.bitstreamQueue[0], queuedBitstream)
        XCTAssertNil(startupMemory)
        
        driver.isRunning = false
    }

    /// Test that any bitstream is freed once the next queued bitstream is transmitting.
    func testQueueRemovesOnNextTransmitting() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        
        // Mark the start bitstream repeating, and the queued bitstream as transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(driver.bitstreamQueue[1])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        
        var bitstream2 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0xcafebabe), count: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0x99c0ffee), count: 32)
        
        try! driver.queue(bitstream: bitstream2)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        
        weak var previousMemory = driver.bitstreamQueue[0].memory
        let queuedBitstream = driver.bitstreamQueue[1]
        
        // Mark the previous bitstream repeating, and the queued bitstream as transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(queuedBitstream)
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }

        // The previous bitstream should have been removed from the queue and its memory freed.
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        XCTAssertEqual(driver.bitstreamQueue[0], queuedBitstream)
        XCTAssertNil(previousMemory)
        
        driver.isRunning = false
    }

    /// Test that when we queue a bitstream and mark it to stop after, it transfers to a stop bitstream.
    func testQueueStopBitstream() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream, repeating: false)
        
        // There should be three queued bitstreams, the startup, the queued, and now the stop bitstream.
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        let queuedBitstream = driver.bitstreamQueue[1]
        let stopBitstream = driver.bitstreamQueue[2]

        // Make sure the queued bitstream points to the stop bitstream.
        var controlBlocks = queuedBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        XCTAssertGreaterThanOrEqual(queuedBitstream.breakpoints.count, 1)
        for breakpoint in queuedBitstream.breakpoints {
            let nextControlBlockAddress = controlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress
            XCTAssertGreaterThanOrEqual(nextControlBlockAddress, stopBitstream.busAddress)
            XCTAssertLessThan(nextControlBlockAddress, stopBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * stopBitstream.controlBlocks.count)
        }
        
        // Make sure that the stop bitstream breakpoints point at the zero address.
        controlBlocks = stopBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        XCTAssertGreaterThanOrEqual(stopBitstream.breakpoints.count, 1)
        for breakpoint in stopBitstream.breakpoints {
            XCTAssertEqual(controlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress, DMAControlBlock.stopAddress)
        }
        
        driver.isRunning = false
    }

    /// Test that the stop bitstream is removed if DMA goes inactive once it's finished transmitting.
    func testQueueRemovesSelfOnStop() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream, repeating: false)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        weak var queuedMemory = driver.bitstreamQueue[1].memory
        weak var stopMemory = driver.bitstreamQueue[2].memory

        // Mark the start bitstream repeating, and the queued bitstream as transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(driver.bitstreamQueue[1])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        // The startup bitstream should have been removed from the queue, with the queued and stop ones remaining and still not freed.
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        XCTAssertNotNil(queuedMemory)
        XCTAssertNotNil(stopMemory)
        
        // Now mark the queued bitstream as repeating, and the stop bitstream as transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(driver.bitstreamQueue[1])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }

        // The queued bitstream should now have been removed from the queue as well, with only the stop one remaining and still not freed.
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        XCTAssertNil(queuedMemory)
        XCTAssertNotNil(stopMemory)

        // Mark DMA inactive, amnd the stop bitstream as transmitted/repeating. It should remove itself from the queue, and free its memory.
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)
        dma.controlStatus.remove(.active)
        
        markRepeating(driver.bitstreamQueue[0])
        XCTAssertEqual(driver.dispatchGroup.wait(timeout: .now() + .seconds(1)), .success)

        XCTAssertEqual(driver.bitstreamQueue.count, 0)
        XCTAssertNil(stopMemory)
        
        driver.isRunning = false
    }
    
    /// Test that when we queue a bitstream after a stop bitstream, the stop bitstream is transferred to the new start bitstream.
    func testQueueAfterStop() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream1 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream1, repeating: false)
        
        // There should be three queued bitstreams, the startup, the queued, and now the stop bitstream.
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        let stopBitstream = driver.bitstreamQueue[2]

        // Skip to the stop bitstream being transmitting and the others repeating.
        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        markTransmitting(driver.bitstreamQueue[2])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }

        // Queue another bitstream. The stop bitstream should be first in the queue, and the new bitstream after it.
        var bitstream2 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0xcafebabe), count: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0x99c0ffee), count: 32)
        
        try! driver.queue(bitstream: bitstream2)

        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        XCTAssertEqual(driver.bitstreamQueue[0], stopBitstream)
        let startBitstream = driver.bitstreamQueue[1]

        // Make sure that the stop bitstream breakpoints now point at the new bitstream.
        let controlBlocks = stopBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        XCTAssertGreaterThanOrEqual(stopBitstream.breakpoints.count, 1)
        for breakpoint in stopBitstream.breakpoints {
            let nextControlBlockAddress = controlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress
            XCTAssertGreaterThanOrEqual(nextControlBlockAddress, startBitstream.busAddress)
            XCTAssertLessThan(nextControlBlockAddress, startBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * startBitstream.controlBlocks.count)
        }
        
        driver.isRunning = false
    }

    /// Test that if a new bitstream is queued after a stop one, and before it is transmitted, it's not removed from the queue twice.
    func testQueueAfterStopDoesntDoubleRemove() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream1 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream1, repeating: false)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        weak var stopMemory = driver.bitstreamQueue[2].memory
        
        // Skip to the stop bitstream being transmitting and the others repeating.
        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        markTransmitting(driver.bitstreamQueue[2])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        XCTAssertNotNil(stopMemory)

        // Queue another bitstream
        var bitstream2 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0xcafebabe), count: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0x99c0ffee), count: 32)

        try! driver.queue(bitstream: bitstream2)

        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        let startBitstream = driver.bitstreamQueue[1]

        // Now mark the previous stop bitstream as repeating (ended), and the new one as transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(driver.bitstreamQueue[1])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }

        // Make sure the new one is still in the queue, but the old one is freed.
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        XCTAssertEqual(driver.bitstreamQueue[0], startBitstream)
        XCTAssertNil(stopMemory)

        driver.isRunning = false
    }
    
    /// Test that when we queue a bitstream after the stop bitstream has finished transmitting, but before we've noticed, the stop bitstream is transferred to the new start bitstream.
    func testQueueAfterDMAInactive() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream1 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream1, repeating: false)
        
        // There should be three queued bitstreams, the startup, the queued, and now the stop bitstream.
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        let stopBitstream = driver.bitstreamQueue[2]
        
        // Skip to the stop bitstream being transmitting and the others repeating.
        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        markTransmitting(driver.bitstreamQueue[2])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        // Remove the active bit, simulating the difference between it being processed and our code noticing.
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)
        dma.controlStatus.remove(.active)
        
        // Queue another bitstream. The stop bitstream should be first in the queue, and the new bitstream after it.
        var bitstream2 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0xcafebabe), count: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0x99c0ffee), count: 32)
        
        try! driver.queue(bitstream: bitstream2)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        XCTAssertEqual(driver.bitstreamQueue[0], stopBitstream)
        let startBitstream = driver.bitstreamQueue[1]

        // Make sure that the DMA is reactivated, and pointed at the new start bitstream.
        XCTAssertTrue(dma.controlStatus.contains(.active))
        XCTAssertEqual(dma.controlBlockAddress, startBitstream.busAddress)
        
        driver.isRunning = false
    }

    /// Test that if a new bitstream is queued after the stop bitstream has finished transmitting, but before we've noticed, it's not removed from the queue twice.
    func testQueueAfterDMAInactiveDoesntDoubleRemove() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream1 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream1.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream1, repeating: false)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        weak var stopMemory = driver.bitstreamQueue[2].memory
        
        // Skip to the stop bitstream being transmitting and the others repeating.
        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        markTransmitting(driver.bitstreamQueue[2])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        XCTAssertNotNil(stopMemory)
        
        // Remove the active bit, simulating the difference between it being processed and our code noticing.
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)
        dma.controlStatus.remove(.active)
        
        // Queue another bitstream
        var bitstream2 = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0xcafebabe), count: 32)
        bitstream2.append(physicalBits: Int(bitPattern: 0x99c0ffee), count: 32)
        
        try! driver.queue(bitstream: bitstream2)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        let startBitstream = driver.bitstreamQueue[1]
        
        // Now mark the previous stop bitstream as repeating (ended), simulating us catching up and noticing, and the new one as transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markTransmitting(driver.bitstreamQueue[1])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        // Make sure the new one is still in the queue, but the old one is freed.
        XCTAssertEqual(driver.bitstreamQueue.count, 2)
        XCTAssertEqual(driver.bitstreamQueue[0], startBitstream)
        XCTAssertNil(stopMemory)
        
        driver.isRunning = false
    }
    
    
    // MARK: Stop.
    
    /// Test that we can append a power off bitstream to any.
    func testStop() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream)
        
        try! driver.stop { }
        
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        let queuedBitstream = driver.bitstreamQueue[1]
        let stopBitstream = driver.bitstreamQueue[2]

        // Make sure the queued bitstream points to the stop bitstream.
        var controlBlocks = queuedBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        XCTAssertGreaterThanOrEqual(queuedBitstream.breakpoints.count, 1)
        for breakpoint in queuedBitstream.breakpoints {
            let nextControlBlockAddress = controlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress
            XCTAssertGreaterThanOrEqual(nextControlBlockAddress, stopBitstream.busAddress)
            XCTAssertLessThan(nextControlBlockAddress, stopBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * stopBitstream.controlBlocks.count)
        }
        
        // Make sure that the stop bitstream breakpoints point at the zero address.
        controlBlocks = stopBitstream.memory!.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        XCTAssertGreaterThanOrEqual(stopBitstream.breakpoints.count, 1)
        for breakpoint in stopBitstream.breakpoints {
            XCTAssertEqual(controlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress, DMAControlBlock.stopAddress)
        }
        
        driver.isRunning = false
    }
    
    /// Test that the stop bitstream is removed if DMA goes inactive once it's finished transmitting.
    func testStopRemovesSelf() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream)
        
        try! driver.stop { }
        
        XCTAssertEqual(driver.bitstreamQueue.count, 3)
        
        weak var stopMemory = driver.bitstreamQueue[2].memory
        
        // Fast forward to the stop bitstream transmitting.
        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        markTransmitting(driver.bitstreamQueue[2])
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        
        // Stop should not yet be freed.
        XCTAssertEqual(driver.bitstreamQueue.count, 1)
        XCTAssertNotNil(stopMemory)
        
        // Mark DMA inactive, amnd the stop bitstream as transmitted/repeating. It should remove itself from the queue, and free its memory.
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)
        dma.controlStatus.remove(.active)
        
        markRepeating(driver.bitstreamQueue[0])
        XCTAssertEqual(driver.dispatchGroup.wait(timeout: .now() + .seconds(1)), .success)
        
        XCTAssertEqual(driver.bitstreamQueue.count, 0)
        XCTAssertNil(stopMemory)
        
        driver.isRunning = false
    }

    /// Test that the stop bitstream completion handler is called.
    func testStopCompletionHandler() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        var bitstream = Bitstream(bitDuration: driver.bitDuration, wordSize: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xdeadbeef), count: 32)
        bitstream.append(physicalBits: Int(bitPattern: 0xcafed00d), count: 32)
        
        try! driver.queue(bitstream: bitstream)
        
        // The completion handler is asynchronous after the completion, so use a semaphore to wait for it.
        var completionHandlerRun = false
        let completionSemaphore = DispatchSemaphore(value: 0)
        try! driver.stop {
            completionHandlerRun = true
            completionSemaphore.signal()
        }
        
        Thread.sleep(forTimeInterval: 0.1)
        driver.dispatchQueue.sync { }
        XCTAssertFalse(completionHandlerRun)

        // Mark DMA inactive, amnd the stop bitstream as transmitted/repeating.
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)
        dma.controlStatus.remove(.active)

        markRepeating(driver.bitstreamQueue[0])
        markRepeating(driver.bitstreamQueue[1])
        markRepeating(driver.bitstreamQueue[2])
        XCTAssertEqual(driver.dispatchGroup.wait(timeout: .now() + .seconds(1)), .success)
        
        XCTAssertEqual(completionSemaphore.wait(timeout: .now() + .seconds(1)), .success)
        
        XCTAssertTrue(completionHandlerRun)
        
        driver.isRunning = false
    }
    
    /// Test that stop works when stopped.
    ///
    /// Only the completion handler should be called.
    func testStopWhenStopped() {
        let driver = Driver(raspberryPi: raspberryPi)
        driver.isRunning = true
        
        // The completion handler is asynchronous after the completion, so use a semaphore to wait for it.
        var completionHandlerRun = false
        let completionSemaphore = DispatchSemaphore(value: 0)
        try! driver.stop {
            completionHandlerRun = true
            completionSemaphore.signal()
        }
        
        XCTAssertEqual(driver.bitstreamQueue.count, 0)
        XCTAssertEqual(completionSemaphore.wait(timeout: .now() + .seconds(1)), .success)
        
        XCTAssertTrue(completionHandlerRun)
        
        driver.isRunning = false
    }

    
    // MARK: Other tests
    
    /// Test that the power off bitstream, when parsed. has no delayed events in its breakpoints.
    func testPowerOffBitstreamHasNoDelayedEvents() {
        let driver = Driver(raspberryPi: raspberryPi)

        var queuedBitstream = QueuedBitstream(raspberryPi: raspberryPi)
        try! queuedBitstream.parseBitstream(driver.powerOffBitstream)
        
        XCTAssertEqual(queuedBitstream.breakpoints.count, 1)
        
        XCTAssertEqual(queuedBitstream.breakpoints[0].delayedEvents.events.count, 0)
    }
    
}

extension DriverTests {
    
    static var allTests = {
        return [
            ("testQueueStartBitstream", testQueueStartBitstream),
            ("testQueueCompletionHandler", testQueueCompletionHandler),
            ("testQueueWhileTransmitting", testQueueWhileTransmitting),
            ("testQueueWhileRepeating", testQueueWhileRepeating),
            ("testQueueRemovesStartOnFirstTransmitting", testQueueRemovesStartOnFirstTransmitting),
            ("testQueueRemovesOnNextTransmitting", testQueueRemovesOnNextTransmitting),
            ("testQueueStopBitstream", testQueueStopBitstream),
            ("testQueueRemovesSelfOnStop", testQueueRemovesSelfOnStop),
            ("testQueueAfterStop", testQueueAfterStop),
            ("testQueueAfterStopDoesntDoubleRemove", testQueueAfterStopDoesntDoubleRemove),
            ("testQueueAfterDMAInactive", testQueueAfterDMAInactive),
            ("testQueueAfterDMAInactiveDoesntDoubleRemove", testQueueAfterDMAInactiveDoesntDoubleRemove),
            
            ("testStop", testStop),
            ("testStopRemovesSelf", testStopRemovesSelf),
            ("testStopCompletionHandler", testStopCompletionHandler),
            ("testStopWhenStopped", testStopWhenStopped),
            
            ("testPowerOffBitstreamHasNoDelayedEvents", testPowerOffBitstreamHasNoDelayedEvents),
        ]
    }()

}
