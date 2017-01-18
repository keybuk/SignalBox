//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import RaspberryPi


/// Errors that can be thrown by the DMA Driver.
public enum DriverError : Error {
    
    /// The DCC Bitstream contains no data to be transmitted.
    case bitstreamContainsNoData

}

struct Driver {
    
    public static let dccGpio = 18
    public static let railComGpio = 17
    public static let debugGpio = 19
    
    let raspberryPi: RaspberryPi
    
    init(raspberryPi: RaspberryPi) {
        self.raspberryPi = raspberryPi
    }

}


/// DMA Control Blocks and accompanying Data parsed from a DCC `Bitstream`.
///
/// Initialize with a `Bitstream` to generate the appropriate DMA Control Blocks and Data for use with `Driver`.
///
/// The principle difficulty is that the PWM doesn't immediately begin outputting the word written after a DREQ, which requires that associated GPIO events such as the RailCom cutout and Debug period have to be delayed relative to the words they are intended to accompany. This ultimately requires in some cases that the bitstream loop be partially or even completely unrolled in order to generate a correct repeating output.
struct QueuedBitstream {
 
    /// Raspberry Pi hardware information.
    let raspberryPi: RaspberryPi
    
    /// DMA Control Blocks parsed from the bitstream.
    ///
    /// Since the physical uncached addresses are not yet known, the values of `sourceAddress` are offsets in bytes from the start of the `data` array; and the values of `destinationAddress`, and `nextControlBlockAddress` are offsets in bytes from the start of the `controlBlocks` array if they are below `RaspberryPi.peripheralBusAddress`.
    var controlBlocks: [DMAControlBlock] = []
    
    /// Data parsed from the bitstream.
    ///
    /// The first value is always the flag used by the start and end control blocks and begins as zero.
    var data: [Int] = [ 0 ]

    /// Parse a bitstream.
    ///
    /// - Parameters:
    ///   - raspberryPi: Raspberry Pi hardware information.
    ///   - bitstream: the `Bitstream` to be parsed.
    ///
    /// - Throws:
    ///   `DriverError.bitstreamContainsNoData` if `bitstream` is missing data records, which may include within a repeating section. Recommended recovery is to add preamble bits and try again.
    init(raspberryPi: RaspberryPi, bitstream: Bitstream) throws {
        self.raspberryPi = raspberryPi
        
        try parseBitstream(bitstream)
    }
    
    /// Adds a DMA Control Block for the start of a bitstream.
    ///
    /// The start control block is used to detect when a bitstream has begun outputting; it writes the value 1 to the first data item and then points at the first true control block in the sequence. Thus the `Driver` can watch the value of this field, and know that once it changes from zero, it can free up any memory associated with the previously running bitstream.
    mutating func addControlBlockForStart() {
        controlBlocks.append(DMAControlBlock(
            transferInformation: [ .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * data.count,
            destinationAddress: 0,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * (controlBlocks.count + 1)))
        data.append(1)
    }
    
    /// Adds a DMA Control Block for the end of a bitstream.
    ///
    /// The end control block is used to detect when a bitstream has completely output at least once; it writes the value -1 to the first date item and then points back to the appropriate looping control block. Thus the `Driver` can watch the value of this field, and know that once it changes to below zero, the bitstream has been output at least once and it can move onto the next queued bitstream if one exists.
    ///
    /// - Parameters:
    ///   - next: the index within `controlBlocks` of the control block to loop back to.
    mutating func addControlBlockForEnd(next nextIndex: Int) {
        controlBlocks.append(DMAControlBlock(
            transferInformation: [ .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * data.count,
            destinationAddress: 0,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * nextIndex))
        data.append(-1)
    }
    
    /// Adds a DMA Control Block and accompanying data for a section of bitstream data.
    ///
    /// The simplest form of control block, `words` are appended directly to `data` and the control block writes them one at a time into the PWM FIFO.
    ///
    /// - Parameters:
    ///   - words: data to be written to the PWM FIFO.
    mutating func addControlBlockForData(_ words: [Int]) {
        controlBlocks.append(DMAControlBlock(
            transferInformation: [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationDREQ, .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * data.count,
            destinationAddress: raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset,
            transferLength: MemoryLayout<Int>.stride * words.count,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * (controlBlocks.count + 1)))
        data.append(contentsOf: words)
    }
    
    /// Adds a DMA Control Block to adjust the PWM Range register.
    ///
    /// Follows a data control block where the final word is of a different size than those before it, by following with a write to the PWM Range register when the PWM nexts raises a DREQ, the PWM will adjust the Range of the word we had previously written.
    ///
    /// - Parameters:
    ///   - range: new range in bits.
    mutating func addControlBlockForRange(_ range: Int) {
        controlBlocks.append(DMAControlBlock(
            transferInformation: [ .noWideBursts, .peripheralMapping(.pwm), .destinationDREQ, .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * data.count,
            destinationAddress: raspberryPi.peripheralBusAddress + PWM.offset + PWM.channel1RangeOffset,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * (controlBlocks.count + 1)))
        data.append(range)
    }
    
    /// Adds a DMA Control Block to set and clear GPIOs.
    ///
    /// Since the GPIO Registers are set/clear pairs, only the GPIOs described in `events` are changed, others are left alone. Should multiple events for a single GPIO be present in `events`, only the last is used.
    ///
    /// - Parameters:
    ///   - events: set of bitstream events corresponding to GPIO changes.
    mutating func addControlBlockForGPIO(_ events: [BitstreamEvent]) {
        assert(!events.isEmpty, "Shouldn't create a GPIO control block for empty events")
        var gpioSet = GPIOBitField()
        var gpioClear = GPIOBitField()
        
        for event in events {
            switch event {
            case .railComCutoutStart:
                gpioSet[Driver.railComGpio] = false
                gpioClear[Driver.railComGpio] = true
            case .railComCutoutEnd:
                gpioClear[Driver.railComGpio] = false
                gpioSet[Driver.railComGpio] = true
            case .debugStart:
                gpioClear[Driver.debugGpio] = false
                gpioSet[Driver.debugGpio] = true
            case .debugEnd:
                gpioSet[Driver.debugGpio] = false
                gpioClear[Driver.debugGpio] = true
            default:
                fatalError("Unexpected non-GPIO event \(event)")
            }
        }
        
        // Write out the GPIO control block specially. Each Set/Clear register cluster is two 32-bit integers long, and separated by one 32-bit integer.
        // Use the 2D Mode Stride function to arrange this, writing 2 × 2 words, with a 1 word stride at the destination but not the source.
        controlBlocks.append(DMAControlBlock(
            transferInformation: [ .noWideBursts, .peripheralMapping(.pwm), .sourceAddressIncrement, .destinationAddressIncrement, .destinationDREQ, .tdMode, .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * data.count,
            destinationAddress: raspberryPi.peripheralBusAddress + GPIO.offset + GPIO.outputSetOffset,
            transferLength: DMAControlBlock.tdTransferLength(x: MemoryLayout<Int>.stride * 2, y: 2),
            tdModeStride: DMAControlBlock.tdModeStride(source: 0, destination: MemoryLayout<Int>.stride),
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * (controlBlocks.count + 1)))
        
        data.append(gpioSet.field0)
        data.append(gpioSet.field1)
        data.append(gpioClear.field0)
        data.append(gpioClear.field1)
    }

    /// Parse a `Bitstream`.
    ///
    /// - Parameters:
    ///   - bitstream: the `Bitstream` to be parsed.
    ///
    /// - Throws:
    ///   `DriverError.bitstreamContainsNoData` if `bitstream` is missing data records, which may include within a repeating section. Recommended recovery is to add preamble bits and try again.
    mutating func parseBitstream(_ bitstream: Bitstream) throws  {
        addControlBlockForStart()
        
        // Keep track of the current range register value, since we don't know what it was prior to this bitstream beginning, use zero so that the first data event will always set it correctly.
        var range: Int = 0

        // For efficiency, we collect multiple consecutive words of data together into a single control block, and only break where necessary. For loop unrolling we track the index within the bitstream that the `words` array began, and the set of delayed events at each of those points.
        var words: [Int] = []
        var wordsIndex = bitstream.endIndex
        var wordsDelayedEvents: [Array.Index: DelayedEvents] = [:]
        
        // As we output control blocks for data, we keep track of the map between index within the bitstream and index within the control blocks array, so we can loop back to them. After we exit the loop, the `loopControlBlockIndex` contains the appropraite control block index for the end control block.
        var controlBlockIndex: [Array.Index: Int] = [:]
        var loopControlBlockIndex = 0

        // Track the set of GPIO events that are being delayed so that they line up with the correct PWM word.
        var delayedEvents = DelayedEvents()

        // Usually we loop through the entire bitstream, but if the bitstream contains a repeating section marker, we only loop through the latter part on subsequent iterations.
        var restartFromIndex = bitstream.startIndex
    
        unroll: while true {
            var foundData = false
            for index in bitstream.suffix(from: restartFromIndex).indices {
                let event = bitstream[index]
                switch event {
                case let .data(word: word, size: size):
                    foundData = true
                    
                    // We can only break out of the loop here if this data in the prior iteration had the same set of delayed events that we do now.
                    if let previousDelayedEvents = wordsDelayedEvents[index],
                        previousDelayedEvents == delayedEvents
                    {
                        // Generally we expect that to mean that this data began a control block in the prior iteration, in which case that control block becomes our loop target and we're done.
                        if let previousControlBlockIndex = controlBlockIndex[index] {
                            loopControlBlockIndex = previousControlBlockIndex
                            break unroll
                        }
                        
                        // But it can also mean that we've consumed nothing but data and looped back to ourselves, in which case we just break out knowing we'll write out that data, and set that to be the loop target.
                        if index == wordsIndex {
                            loopControlBlockIndex = controlBlocks.count
                            break unroll
                        }
                    }
                    
                    // If this data event will begin a new control block, track the index and current set of delayed events for comparison above.
                    if words.isEmpty {
                        wordsIndex = index
                        wordsDelayedEvents[wordsIndex] = delayedEvents
                    }
                    words.append(word)
                    
                    // Adjust all delayed events downwards by one, and return the set due now.
                    let dueEvents = delayedEvents.countdown()
                    
                    // Don't output the control block if we can still append more data to it.
                    if size == range && dueEvents.isEmpty {
                        break
                    }
                    
                    // Output the control block, and record the index for it.
                    controlBlockIndex[wordsIndex] = controlBlocks.count
                    addControlBlockForData(words)
                    words.removeAll()
                    
                    // Follow with a range change if the size of the final word doesn't match its current value.
                    if size != range {
                        addControlBlockForRange(size)
                        range = size
                    }
                    
                    // Follow with a GPIO control block if events became due.
                    if !dueEvents.isEmpty {
                        addControlBlockForGPIO(dueEvents)
                    }
                case .railComCutoutStart, .railComCutoutEnd, .debugStart, .debugEnd:
                    // GPIO events are always delayed.
                    delayedEvents.addEvent(event)
                case .loopStart:
                    // Adjust the loop so that we skip past ourselves on the next iteration.
                    restartFromIndex = bitstream.index(after: index)
                    
                    // If there is pending data, we write it out here; this isn't strictly necessary because it'll happen anyway, but it results in a nice clean data break at the loop point and avoids unnecessary unrolling. We cheat and don't bother with the `controlBlockIndex` and `wordsDelayedEvents` arrays here because we know that we'll never come back to them.
                    if !words.isEmpty {
                        addControlBlockForData(words)
                        words.removeAll()
                    }
                }
            }
            
            guard foundData else { throw DriverError.bitstreamContainsNoData }
        }
        
        if !words.isEmpty {
            // Some trailing words in the bitstream need to be written out.
            addControlBlockForData(words)
            words.removeAll()
        }
        
        addControlBlockForEnd(next: loopControlBlockIndex)
    }
    
    /// Memory region containing copy of bitstream in uncached memory.
    ///
    /// The value is `nil` until `commit()` is called.
    var memory: MemoryRegion?
    
    /// Make the bitstream available to the DMA engine.
    ///
    /// Allocates a region of memory within the uncached alias and initializes it from the parsed bitstream, which will have its addresses updated to refer to the bus address of the memory region.
    ///
    /// - Throws:
    ///   `MailboxError` or `RaspberryPiError` if the memory region cannot be allocated.
    mutating func commit() throws {
        guard self.memory == nil else { fatalError("Queued bitstream already committed to uncached memory.") }

        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
        let dataSize = MemoryLayout<Int>.stride * data.count
        
        let memory = try raspberryPi.allocateUncachedMemory(minimumSize: controlBlocksSize + dataSize)
        
        for index in controlBlocks.indices {
            if controlBlocks[index].sourceAddress < raspberryPi.peripheralBusAddress {
                controlBlocks[index].sourceAddress += memory.busAddress + controlBlocksSize
            }
            if controlBlocks[index].destinationAddress < raspberryPi.peripheralBusAddress {
                controlBlocks[index].destinationAddress += memory.busAddress + controlBlocksSize
            }
            controlBlocks[index].nextControlBlockAddress += memory.busAddress
        }

        memory.pointer.bindMemory(to: DMAControlBlock.self, capacity: controlBlocks.count).initialize(from: controlBlocks)
        memory.pointer.advanced(by: controlBlocksSize).bindMemory(to: Int.self, capacity: data.count).initialize(from: data)
        
        self.memory = memory
    }

}

/// Ordered queue of delayed `BitstreamEvent`.
///
/// This is a helper structure used by `QueuedBitstream` to encapsulate its delayed events set, and provide equatability.
struct DelayedEvents : Equatable {
    
    /// Number of DREQ signals to delay non-PWM events to synchronize with the PWM output.
    ///
    /// Writing to the PWM FIFO does not immediately result in output, instead the word that we write is first placed into the FIFO, and then next into the PWM's internal queue, before being output. Thus to synchronize an external event, such as a GPIO, with the PWM output we delay it by this many DREQ signals.
    static let eventDelay = 2

    /// Set of events being delayed, along with the current delay.
    var events: [(event: BitstreamEvent, delay: Int)] = []

    /// Add an event with the default delay.
    ///
    /// - Parameters:
    ///   - event: event to be added.
    mutating func addEvent(_ event: BitstreamEvent) {
        events.append((event: event, delay: DelayedEvents.eventDelay))
    }

    /// Reduce the delay of all events.
    ///
    /// - Returns: the set of events that are now due.
    mutating func countdown() -> [BitstreamEvent] {
        var dueEvents: [BitstreamEvent] = []
        while events.count > dueEvents.count && events[dueEvents.count].delay == 1 {
            dueEvents.append(events[dueEvents.count].event)
        }
        
        events.removeFirst(dueEvents.count)
        
        for index in events.indices {
            assert(events[index].delay > 1, "events must be sorted in ascending order")
            events[index] = (event: events[index].event, delay: events[index].delay - 1)
        }
        
        return dueEvents
    }
    
    static func ==(lhs: DelayedEvents, rhs: DelayedEvents) -> Bool {
        guard lhs.events.count == rhs.events.count else { return false }
        
        for (lhsEvent, rhsEvent) in zip(lhs.events, rhs.events) {
            guard lhsEvent.event == rhsEvent.event && lhsEvent.delay == rhsEvent.delay else { return false }
        }
        
        return true
    }
    
}
