//
//  QueuedBitstream.swift
//  SignalBox
//
//  Created by Scott James Remnant on 2/1/17.
//
//

import OldRaspberryPi


/// Errors that can be thrown by bitstream parsing.
public enum QueuedBitstreamError : Error {
    
    /// Bitstream contains no data to be transmitted.
    case containsNoData
    
    /// Bitstream begins with a breakpoint.
    case breakpointAtStart

}


/// DMA Control Blocks and accompanying Data parsed from a DCC `Bitstream`.
///
/// Initialize with a `Bitstream` to generate the appropriate DMA Control Blocks and Data for use with `Driver`.
///
/// The principle difficulty is that the PWM doesn't immediately begin outputting the word written after a DREQ, which requires that associated GPIO events such as the RailCom cutout and Debug period have to be delayed relative to the words they are intended to accompany. This ultimately requires in some cases that the bitstream loop be partially or even completely unrolled in order to generate a correct repeating output.
public struct QueuedBitstream : CustomDebugStringConvertible, Equatable {
    
    /// Raspberry Pi hardware information.
    public let raspberryPi: RaspberryPi
    
    /// Size of words.
    ///
    /// Generally the platform's word size, but can be overriden at initialization for testing purposes.
    let wordSize: Int
    
    /// DMA Control Blocks parsed from the bitstream.
    ///
    /// Since the physical uncached addresses are not yet known, the values of `sourceAddress` are offsets in bytes from the start of the `data` array; and the values of `destinationAddress`, and `nextControlBlockAddress` are offsets in bytes from the start of the `controlBlocks` array if they are below `RaspberryPi.peripheralBusAddress`.
    public private(set) var controlBlocks: [DMAControlBlock] = []
    
    /// Data parsed from the bitstream.
    ///
    /// The first value is always the flag used by the start and end control blocks and begins as zero.
    public private(set) var data: [Int] = [ 0 ]
    
    /// Breakpoints that were present in the bitstream.
    public private(set) var breakpoints: [Breakpoint] = []
    
    init(raspberryPi: RaspberryPi, wordSize: Int) {
        self.raspberryPi = raspberryPi
        self.wordSize = wordSize
    }
    
    public init(raspberryPi: RaspberryPi) {
        self.init(raspberryPi: raspberryPi, wordSize: MemoryLayout<Int>.size * 8)
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
    mutating func addControlBlockForEnd() {
        controlBlocks.append(DMAControlBlock(
            transferInformation: [ .waitForWriteResponse ],
            sourceAddress: MemoryLayout<Int>.stride * data.count,
            destinationAddress: 0,
            transferLength: MemoryLayout<Int>.stride,
            tdModeStride: 0,
            nextControlBlockAddress: MemoryLayout<DMAControlBlock>.stride * (controlBlocks.count + 1)))
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
                gpioSet[Driver.railComGPIO] = false
                gpioClear[Driver.railComGPIO] = true
            case .railComCutoutEnd:
                gpioClear[Driver.railComGPIO] = false
                gpioSet[Driver.railComGPIO] = true
            case .debugStart:
                gpioClear[Driver.debugGPIO] = false
                gpioSet[Driver.debugGPIO] = true
            case .debugEnd:
                gpioSet[Driver.debugGPIO] = false
                gpioClear[Driver.debugGPIO] = true
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
    
    /// Adjusts the last control block's `nextControlBlockAddress`.
    ///
    /// - Parameters:
    ///   - next: offset of control block to change to; if `nil`, the stop address is used instead.
    mutating func setNextControlBlock(_ next: Int?) {
        assert(!controlBlocks.isEmpty, "Cannot be called without control blocks.")

        // Since we never repeat back to the start control block, we can use the value zero as a placeholder for the stop address.
        controlBlocks[controlBlocks.index(before: controlBlocks.endIndex)].nextControlBlockAddress = MemoryLayout<DMAControlBlock>.stride * (next ?? 0)
    }
    
    /// Offsets of control block written out for the bitstream.
    ///
    /// This is indexed by `BitstreamState`, a structure that rolls up the combination of the index within the bitstream, current range value, and set of delayed events. This ensures that a control block is only used if it is an exact match.
    ///
    /// Note that `BitstreamState` considers a `range` of 0 in this tructure to be equal to anything, since it only occurs for the first data and is always followed by a range change.
    var controlBlockOffsets: [BitstreamState: Int] = [:]
    
    /// Helper structure to encapsulate the state of the bitstream.
    ///
    /// Two bitstream states are considered identical if they have the same index with in the bitstream, the same set of delayed events, and either the same range or the left hand side has a range of 0.
    /// This special case exists only for the very first data block, and allows it to match itself later on (either when unrolling or transferring) when the range is known—this is safe because the very first data block is always followed by a range change anyway.
    struct BitstreamState : Hashable {
        
        /// Index within the bitstream.
        let index: Array<Bitstream>.Index
        
        /// Current value of the range, or 0 to match anything.
        let range: Int
        
        /// Set of delayed events.
        let delayedEvents: DelayedEvents
        
        var hashValue: Int {
            // Range is not included in the hash value since it has unusual equality rules.
            return index.hashValue ^ delayedEvents.hashValue
        }
        
        static func ==(lhs: BitstreamState, rhs: BitstreamState) -> Bool {
            return lhs.index == rhs.index && lhs.delayedEvents == rhs.delayedEvents && (lhs.range == rhs.range || lhs.range == 0)
        }
        
    }

    /// Helper structure to encapsulate an ordered queue of delayed `BitstreamEvent`.
    struct DelayedEvents : Hashable {
        
        /// Set of events being delayed, along with the current delay.
        var events: [(event: BitstreamEvent, delay: Int)] = []
        
        /// Add an event with the default delay.
        ///
        /// - Parameters:
        ///   - event: event to be added.
        mutating func addEvent(_ event: BitstreamEvent) {
            events.append((event: event, delay: Driver.eventDelay))
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
        
        var hashValue: Int {
            return events.reduce(0) {
                $0 ^ $1.event.hashValue ^ $1.delay.hashValue
            }
        }
        
        static func ==(lhs: DelayedEvents, rhs: DelayedEvents) -> Bool {
            guard lhs.events.count == rhs.events.count else { return false }
            
            for (lhsEvent, rhsEvent) in zip(lhs.events, rhs.events) {
                guard lhsEvent.event == rhsEvent.event && lhsEvent.delay == rhsEvent.delay else { return false }
            }
            
            return true
        }
        
    }

    /// Parse a `Bitstream`.
    ///
    /// Outputs a series of control blocks beginning with the start control block, then serializing the bitstream given, then the end control block, and if necessary unrolling the loop so that the output is consistent across delayed events.
    ///
    /// This may be called multiple times before calling `commit` to add different start parameters by passing a `breakpoint` to transfer from, these control blocks will jump into any previously output blocks as soon as possible.
    ///
    /// - Parameters:
    ///   - bitstream: the `Bitstream` to be parsed.
    ///   - breakpoint: optional `Breakpoint` information from another queued bitstream to be resumed from.
    ///   - repeating: when `false`, the loop will not be unrolled and the end block will have a zero `nextControlBlockAddress`.
    ///
    /// - Returns: offset of control block that begins the bitstream.
    ///
    /// - Throws:
    ///   `DriverError.bitstreamContainsNoData` if `bitstream` is missing data records, which may include within a repeating section. Recommended recovery is to add preamble bits and try again.
    @discardableResult
    public mutating func parseBitstream(_ bitstream: Bitstream, transferringFrom breakpoint: Breakpoint? = nil, repeating: Bool = true) throws -> Int {
        guard memory == nil else { fatalError("Queued bitstream already committed to uncached memory.") }

        // Keep track of the current range register value, since we don't know what it was prior to this bitstream beginning, use zero so that the first data event will always set it correctly.
        var range = breakpoint.map({ $0.range }) ?? 0
        
        // Also keep track the set of GPIO events that are being delayed so that they line up with the correct PWM word.
        var delayedEvents = breakpoint.map({ $0.delayedEvents }) ?? DelayedEvents()
        
        // For efficiency, we collect multiple consecutive words of data together into a single control block, and only break where necessary. For loop unrolling we track the bitstream state at the point that the `words` array began.
        var words: [Int] = []
        var wordsState: BitstreamState?
        
        // After we exit the loop, the `loopControlBlockOffset` contains the offset of the appropriate control block index to jump to.
        var loopControlBlockOffset: Array<DMAControlBlock>.Index? = nil
        
        // Usually we loop through the entire bitstream, but if the bitstream contains a repeating section marker, we only loop through the latter part on subsequent iterations.
        var restartFromIndex = bitstream.startIndex
        
        // Write out the start control block, and record the offset where we placed it.
        let startControlBlockOffset = controlBlocks.count
        addControlBlockForStart()
        
        repeat {
            var foundData = false
            var appendEnd = true
            bitstream: for index in bitstream.suffix(from: restartFromIndex).indices {
                let event = bitstream[index]
                switch event {
                case let .data(word: word, size: size):
                    foundData = true
                    
                    // We can break out of the loop if the bitstream state at this point exactly matches a previous state in which we wrote out a control block, in which case that control block becomes the loop target, and we're done.
                    let state = BitstreamState(index: index, range: range, delayedEvents: delayedEvents)
                    if let previousControlBlockOffset = controlBlockOffsets[state] {
                        loopControlBlockOffset = previousControlBlockOffset
                        appendEnd = false
                        break bitstream
                    }
                    
                    // If this data event will begin a new control block, track the index and current set of delayed events for comparison above.
                    if words.isEmpty {
                        wordsState = state
                    }
                    words.append(word)
                    
                    // Adjust all delayed events downwards by one, and return the set due now.
                    let dueEvents = delayedEvents.countdown()
                    
                    // Don't output the control block if we can still append more data to it.
                    if size == range && dueEvents.isEmpty {
                        break
                    }
                    
                    // Output the control block, and record the index for it.
                    controlBlockOffsets[wordsState!] = controlBlocks.count
                    addControlBlockForData(words)
                    words.removeAll()
                    wordsState = nil

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
                    
                    // If there is pending data, we write it out here; this isn't strictly necessary because it'll happen anyway, but it results in a nice clean data break at the loop point and avoids unnecessary unrolling.
                    if !words.isEmpty {
                        controlBlockOffsets[wordsState!] = controlBlocks.count
                        addControlBlockForData(words)
                        words.removeAll()
                        wordsState = nil
                    }
                case .breakpoint:
                    // If there is pending data, write it out.
                    if !words.isEmpty {
                        controlBlockOffsets[wordsState!] = controlBlocks.count
                        addControlBlockForData(words)
                        words.removeAll()
                        wordsState = nil
                    }

                    guard controlBlocks.count > 1 else { throw QueuedBitstreamError.breakpointAtStart }

                    breakpoints.append(Breakpoint(controlBlockOffset: controlBlocks.count - 1, range: range, delayedEvents: delayedEvents))
                }
            }
            
            if !words.isEmpty {
                // Some trailing words in the bitstream need to be written out.
                controlBlockOffsets[wordsState!] = controlBlocks.count
                addControlBlockForData(words)
                words.removeAll()
                wordsState = nil
            }
            
            if appendEnd {
                addControlBlockForEnd()
                breakpoints.append(Breakpoint(controlBlockOffset: controlBlocks.count - 1, range: range, delayedEvents: delayedEvents))
                if !repeating {
                    break
                }

                appendEnd = false
            }
            
            guard foundData else { throw QueuedBitstreamError.containsNoData }
        } while loopControlBlockOffset == nil
        
        setNextControlBlock(loopControlBlockOffset)
        
        return startControlBlockOffset
    }
    
    /// Memory region containing copy of bitstream in uncached memory.
    ///
    /// The value is `nil` until `commit()` is called.
    public private(set) var memory: MemoryRegion?
    
    /// Make the bitstream available to the DMA engine.
    ///
    /// Allocates a region of memory within the uncached alias and initializes it from the parsed bitstream, which will have its addresses updated to refer to the bus address of the memory region.
    ///
    /// - Throws:
    ///   `MailboxError` or `RaspberryPiError` if the memory region cannot be allocated.
    public mutating func commit() throws {
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
            if controlBlocks[index].nextControlBlockAddress > 0 {
                controlBlocks[index].nextControlBlockAddress += memory.busAddress
            } else {
                controlBlocks[index].nextControlBlockAddress = DMAControlBlock.stopAddress
            }
        }
        
        memory.pointer.initializeMemory(as: DMAControlBlock.self, from: controlBlocks, count: controlBlocks.count)
        memory.pointer.advanced(by: controlBlocksSize).initializeMemory(as: Int.self, from: data, count: data.count)
        
        self.memory = memory
        self.controlBlockOffsets.removeAll()
    }
    
    /// Bus address of the bitstream in memory.
    ///
    /// This address is within the “‘C’ Alias” and may be handed directly to hardware such as the DMA Engine. To obtain an equivalent address outside the alias, remove RaspberryPi.uncachedAliasBusAddress from this value.
    ///
    /// This value is only available once `commit()` has been called.
    public var busAddress: Int {
        guard let memory = memory else { fatalError("Queued bitstream has not been committed to uncached memory.") }
        return memory.busAddress
    }
    
    /// Indicates whether the bitstream is currently transmitting.
    ///
    /// This value is only available once `commit()` has been called.
    public var isTransmitting: Bool {
        guard let memory = memory else { fatalError("Queued bitstream has not been committed to uncached memory.") }
        
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
        let uncachedData = memory.pointer.advanced(by: controlBlocksSize).assumingMemoryBound(to: Int.self)
        
        return uncachedData[0] != 0
    }
    
    /// Indicates whether the bitstream is currently repeating transmission after the first complete transmission.
    ///
    /// Where the bitstream includes a `.loopStart` event, only the portion after that event is repeated.
    ///
    /// This value is only available once `commit()` has been called.
    public var isRepeating: Bool {
        guard let memory = memory else { fatalError("Queued bitstream has not been committed to uncached memory.") }
        
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
        let uncachedData = memory.pointer.advanced(by: controlBlocksSize).assumingMemoryBound(to: Int.self)
        
        return uncachedData[0] < 0
    }
    
    /// Parse a bitstream for transferring from another.
    ///
    /// Calls `parseBitstream` repeatedly for each breakpoint present in `previousBitstream` and returns a list of transfer offsets corresponding to each breakpoint.
    ///
    /// This is destination part of the process that generates the destination points for the transfer. A full transfer also involves the previous bitstream. for example:
    ///
    ///     let transferOffsets = try nextBitstream.transfer(from: previousBitstream, into: bitstream)
    ///     try nextBitstream.commit()
    ///     previousBitstream.transfer(to: nextBitstream, at: transferOffsets)
    ///
    /// - Parameters:
    ///   - previousBitstream: queued bitstream to transfer from.
    ///   - bitstream: bitstream to parse.
    ///   - repeating: when `false`, the loops will not be unrolled and the end blocks will have a zero `nextControlBlockAddress`.
    ///
    /// - Returns: list of transfer offsets into the new queued bitstream.
    public mutating func transfer(from previousBitstream: QueuedBitstream, into bitstream: Bitstream, repeating: Bool = true) throws -> [Int] {
        guard memory == nil else { fatalError("Queued bitstream already committed to uncached memory.") }

        var transferOffsets: [Int] = []
        for breakpoint in previousBitstream.breakpoints {
            let transferOffset = try parseBitstream(bitstream, transferringFrom: breakpoint, repeating: repeating)
            transferOffsets.append(transferOffset)
        }
        
        return transferOffsets
    }
    
    /// Transfer control to a new queued bitstream.
    ///
    /// Modifies the next block addresses of the uncached copies of the control blocks to transfer control to the new bitstream, with each breakpoint transferred to the corresponding new offset in `transferOffsets`. Note that the uncached copy in `controlBlocks` is not modified.
    ///
    /// The bitstream will only be transferred once at least one full transmission has occurred.
    ///
    /// This is destination part of the process that generates the destination points for the transfer. A full transfer also involves the previous bitstream. for example:
    ///
    ///     let transferOffsets = try nextBitstream.transfer(from: previousBitstream, into: bitstream)
    ///     try nextBitstream.commit()
    ///     previousBitstream.transfer(to: nextBitstream, at: transferOffsets)
    ///
    /// - Parameters:
    ///   - nextBitstream: queued bitstream to transfer control to.
    ///   - transferOffsets: list of control block offsets corresponding to each breakpoint.
    public func transfer(to nextBitstream: QueuedBitstream, at transferOffsets: [Int]) {
        guard let memory = memory else { fatalError("Queued bitstream has not been committed to uncached memory.") }
        assert(breakpoints.count == transferOffsets.count, "Number of transfer offsets must be same as number of breakpoints")

        let uncachedControlBlocks = memory.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count

        // Set the nextControlBlockAddress for each end control block to the associated new transfer offset.
        // We can do this at any time, since these mark the point at which we would be repeating our transmission, and it's always okay to send just one full copy.
        for (breakpoint, transferOffset) in zip(breakpoints, transferOffsets) {
            if uncachedControlBlocks[breakpoint.controlBlockOffset].destinationAddress == busAddress + controlBlocksSize {
                uncachedControlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress = nextBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * transferOffset
            }
        }
        
        // Only change the nextBlockAddress for the rest of the breakpoints if we're already repeating the transmission, since we know we've sent at least one full copy at this point.
        // There's no race between these two blocks:
        // - if we were already repeating, we just cost a little extra time setting the end blocks first.
        // - if we were not repeating, and are still not, we'll transfer at the end control block and transmit exactly one full copy.
        // - if we were not repeating, but are now, and we just missed writing the address, we'll just transfer at the next breakpoint with a slight extra transmission.
        // - if we were not repeating, but are now, and we caught it at an end control block, we transmit exactly one full copy and just cost a little time setting these blocks which aren't going to be used.
        if isRepeating {
            for (breakpoint, transferOffset) in zip(breakpoints, transferOffsets) {
                uncachedControlBlocks[breakpoint.controlBlockOffset].nextControlBlockAddress = nextBitstream.busAddress + MemoryLayout<DMAControlBlock>.stride * transferOffset
            }
        }
    }
    
    /// A textual representation of this instance, suitable for debugging.
    ///
    /// The string is generated by parsing the `controlBlocks` and `data` members.
    public var debugDescription: String {
        var description = "QueuedBitstream:\n"
        
        // Adjust the base of the addresses depending on whether commit() has been called or not.
        let controlBlocksBase: Int
        let dataBase: Int
        if let memory = memory {
            controlBlocksBase = memory.busAddress
            dataBase = memory.busAddress + MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
            
            description += "  committed at " + String(UInt(bitPattern: memory.busAddress), radix: 16) + "\n"
        } else {
            controlBlocksBase = 0
            dataBase = 0
        }
        
        for (offset, controlBlock) in controlBlocks.enumerated() {
            let dataIndex = (controlBlock.sourceAddress - dataBase) / MemoryLayout<Int>.stride
            let dataSize = controlBlock.transferLength / MemoryLayout<Int>.stride
            
            let next = controlBlock.nextControlBlockAddress == 0 ? "⏚" : "\((controlBlock.nextControlBlockAddress - controlBlocksBase) / MemoryLayout<DMAControlBlock>.stride)"
            let bp = breakpoints.filter({ $0.controlBlockOffset == offset }).isEmpty ? "" : " ◆"

            switch controlBlock.destinationAddress {
            case dataBase:
                // Start or End.
                switch data[dataIndex] {
                case 1:
                    description += "  \(offset): Start → \(next)\(bp)\n"
                case -1:
                    description += "  \(offset): End → \(next)\(bp)\n"
                default:
                    description += "  \(offset): Unknown start/end \(data[dataIndex]) → \(next)\(bp)\n"
                }
            case raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset:
                // PWM Data.
                description += "  \(offset): Data → \(next)\(bp)\n"
                for i in dataIndex..<(dataIndex + dataSize) {
                    description += "    \(String(binaryValueOf: data[i], length: wordSize))\n"
                }
            case raspberryPi.peripheralBusAddress + PWM.offset + PWM.channel1RangeOffset:
                // PWM Range.
                description += "  \(offset): Range \(data[dataIndex]) → \(next)\(bp)\n"
            case raspberryPi.peripheralBusAddress + GPIO.offset + GPIO.outputSetOffset:
                // GPIO.
                let setField = GPIOBitField(field0: data[dataIndex], field1: data[dataIndex + 1])
                let clearField = GPIOBitField(field0: data[dataIndex + 2], field1: data[dataIndex + 3])
                
                description += "  \(offset): GPIO → \(next)\(bp)\n"
                if setField[Driver.railComGPIO] {
                    description += "    ↑ RailCom\n"
                }
                if setField[Driver.debugGPIO] {
                    description += "    ↑ Debug\n"
                }
                
                if clearField[Driver.railComGPIO] {
                    description += "    ↓ RailCom\n"
                }
                if clearField[Driver.debugGPIO] {
                    description += "    ↓ Debug\n"
                }
            default:
                description += "  \(offset): Unknown → \(next)\(bp)\n"
            }
        }
        
        return description
    }
    
    public static func ==(lhs: QueuedBitstream, rhs: QueuedBitstream) -> Bool {
        return lhs.controlBlocks == rhs.controlBlocks && lhs.data == rhs.data && lhs.breakpoints == rhs.breakpoints
    }
    
}


/// Breakpoint in a `QueuedBitstream`.
///
/// Collates the location of a breakpooint within a `QueuedBitstream` and the internal state of the bitstraem at that point such that another bitstream can build control blocks to transfer from this point into itself.
public struct Breakpoint : Hashable {

    /// Offset of the control block that can have its `nextControlBlockAddress` changed.
    public let controlBlockOffset: Int
    
    /// PWM Range in effect at this point in the stream.
    let range: Int

    /// Set of delayed events that are pending at this point in the stream.
    let delayedEvents: QueuedBitstream.DelayedEvents
    
    public var hashValue: Int {
        return controlBlockOffset.hashValue ^ range.hashValue ^ delayedEvents.hashValue
    }

    public static func ==(lhs: Breakpoint, rhs: Breakpoint) -> Bool {
        return lhs.controlBlockOffset == rhs.controlBlockOffset && lhs.range == rhs.range && lhs.delayedEvents == rhs.delayedEvents
    }

}

