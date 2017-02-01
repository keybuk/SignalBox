//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import Dispatch

import RaspberryPi


/// Errors that can be thrown by the DMA Driver.
public enum DriverError : Error {
    
    /// Bitstream contains no data to be transmitted.
    case bitstreamContainsNoData

}

public class Driver {
    
    public static let dccGpio = 18
    public static let railComGpio = 17
    public static let debugGpio = 19
    
    public static let dmaChannel = 5
    public static let clockIdentifier: ClockIdentifier = .pwm

    public static let desiredBitDuration: Float = 14.5
    public let bitDuration: Float
    let divisor: Int

    public let raspberryPi: RaspberryPi

    /// Queue of bitstreams.
    ///
    /// The first bitstream in the queue is the one that most recently begun, the last bitstream in the queue is the one that will be repeated.
    ///
    /// - Note: Modifications to this queue must only be made within blocks scheduled on `dispatchQueue`.
    var bitstreamQueue: [QueuedBitstream] = []

    /// Dispatch queue for `bitstreamQueue`.
    let dispatchQueue: DispatchQueue

    /// Indicates whether the Driver is currently running.
    public internal(set) var isRunning = false

    public init(raspberryPi: RaspberryPi) {
        self.raspberryPi = raspberryPi
        self.dispatchQueue = DispatchQueue(label: "com.netsplit.DCC.Driver")
        
        divisor = Int(Driver.desiredBitDuration * 19.2)
        bitDuration = Float(divisor) / 19.2
    }
    
    /// Initialize hardware.
    ///
    /// Sets up the PWM, GPIO and DMA hardware and prepares for a bitstream to be queued. The DMA Engine will not be activated until the first bitstream is queued with `queue(bitstream:)`.
    public func startup() {
        print("DMA Driver startup: divisor \(divisor), bit duration \(bitDuration)µs")

        // Disable both PWM channels, and reset the error state.
        var pwm = raspberryPi.pwm()
        pwm.dmaConfiguration.remove(.enabled)
        pwm.control.remove([ .channel1Enable, .channel2Enable ])
        pwm.status.insert([ .busError, .fifoReadError, .fifoWriteError, .channel1GapOccurred, .channel2GapOccurred, .channel3GapOccurred, .channel4GapOccurred ])

        // Clear the FIFO, and ensure neither channel is consuming from it.
        pwm.control.remove([ .channel1UseFifo, .channel2UseFifo ])
        pwm.control.insert(.clearFifo)
        
        // Set the PWM clock, using the oscillator as a source. In order to ensure consistent timings, use an integer divisor only.
        var clock = raspberryPi.clock(identifier: Driver.clockIdentifier)
        clock.disable()
        clock.control = [ .source(.oscillator), .mash(.integer) ]
        clock.divisor = [ .integer(divisor) ]
        clock.enable()
        
        // Make sure that the DMA Engine is enabled, abort any existing use of it, and clear error state.
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)
        dma.enabled = true
        dma.controlStatus.insert(.abort)
        dma.controlStatus.insert(.reset)
        dma.debug.insert([ .readError, .fifoError, .readLastNotSetError ])

        // Set the DCC GPIO for PWM output.
        var gpio = raspberryPi.gpio(number: Driver.dccGpio)
        gpio.function = .alternateFunction5
        
        // Set the RailCom GPIO for output and clear.
        gpio = raspberryPi.gpio(number: Driver.railComGpio)
        gpio.function = .output
        gpio.value = false
        
        // Set the debug GPIO for output and clear.
        gpio = raspberryPi.gpio(number: Driver.debugGpio)
        gpio.function = .output
        gpio.value = false
        
        // Enable the PWM, using the FIFO in serializer mode, and DREQ signals sent to the DMA Engine.
        pwm.dmaConfiguration = [ .enabled, .dreqThreshold(1), .panicThreshold(1) ]
        pwm.control = [ .channel1UseFifo, .channel1SerializerMode, .channel1Enable ]
        
        // Set the DMA Engine priority levels.
        dma.controlStatus = [ .priorityLevel(8), .panicPriorityLevel(8) ]
        
        // Prime the FIFO, completely filling it. This ensures our attempts to align GPIO and PWM data are successful.
        print("Priming FIFO", terminator: "")
        while !pwm.status.contains(.fifoFull) {
            print(".", terminator: "")
            pwm.fifoInput = 0
        }
        print("")
        
        isRunning = true
        DispatchQueue.global().asyncAfter(deadline: .now() + Driver.watchdogInterval, execute: watchdog)
    }
    
    /// Shutdown hardware.
    ///
    /// Disables the PWM and DMA hardware, and resets the GPIOs to a default state.
    ///
    /// It is essential that this be called before exit, as otherwise the DMA Engine will continue on its programmed sequence and endlessly repeat the last queued bitstream.
    public func shutdown() {
        // Disable the PWM channel.
        var pwm = raspberryPi.pwm()
        pwm.control.remove(.channel1Enable)
        pwm.dmaConfiguration.remove(.enabled)

        // Stop the clock.
        var clock = raspberryPi.clock(identifier: Driver.clockIdentifier)
        clock.disable()

        // Stop the DMA Engine.
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)
        dma.controlStatus.remove(.active)
        dma.controlStatus.insert(.abort)

        // Clear the bitstream queue.
        isRunning = false
        bitstreamQueue.removeAll()
        
        // Restore the DCC GPIO to output, and clear all pins.
        var gpio = raspberryPi.gpio(number: Driver.dccGpio)
        gpio.function = .output
        gpio.value = false
        
        gpio = raspberryPi.gpio(number: Driver.railComGpio)
        gpio.value = false
        
        gpio = raspberryPi.gpio(number: Driver.debugGpio)
        gpio.value = false
    }
    
    /// Queue bitstream.
    ///
    /// - Parameters:
    ///   - bitstream: DCC Bitstream to be queued.
    ///   - completionHandler: Optional block to be run once `bitstream` has been transmitted at least once.
    ///
    /// - Throws:
    ///   Errors from `DriverError`, `MailboxError`, and `RaspberryPiError` on failure.
    public func queue(bitstream: Bitstream, completionHandler: (() -> Void)? = nil) throws {
        var queuedBitstream = try QueuedBitstream(raspberryPi: raspberryPi, bitstream: bitstream)
        queuedBitstream.completionHandler = completionHandler

        try queuedBitstream.commit()
        print("Bitstream duration \(queuedBitstream.duration)µs")
        print("Bus  " + String(UInt(bitPattern: queuedBitstream.busAddress), radix: 16))
        print("Phys " + String(UInt(bitPattern: queuedBitstream.busAddress & ~raspberryPi.uncachedAliasBusAddress), radix: 16))
        
        // Append the new bitstream to the queue, informing the previous item in the queue to transfer to it, or beginning the new item.
        dispatchQueue.sync {
            let previousBitstream = bitstreamQueue.last
            bitstreamQueue.append(queuedBitstream)
            
            if let previousBitstream = previousBitstream {
                previousBitstream.transfer(toBusAddress: queuedBitstream.busAddress)
            } else {
                var dma = raspberryPi.dma(channel: Driver.dmaChannel)
                dma.controlBlockAddress = queuedBitstream.busAddress
                dma.controlStatus.insert(.active)
            }

            // Schedule a repeating check for the new bitstream beginning transmission.
            dispatchQueue.asyncAfter(deadline: .now() + Driver.bitstreamCheckInterval, execute: checkBitstreamIsTransmitting(queuedBitstream, removeFirst: previousBitstream != nil))
        }
    }
    
    /// Interval between bitstream state checks.
    ///
    /// We use a repeated dispatch block of this interval, rather than a loop/sleep, to allow interleaving of checks for multiple queued bitstreams.
    static let bitstreamCheckInterval: DispatchTimeInterval = .milliseconds(1)

    /// Returns block to check whether a bitstream is transmitting yet.
    ///
    /// Once a bitstream begins transmission, we remove the first item from the queue since that is no longer repeating, and then we delay the expected duration of the bitstream before checking whether transmission has complete.
    ///
    /// This method returns a block that is intended to be run on `dispatchQueue`. The block self-reschedules itself at `bitstreamCheckInterval` while the condition is false.
    ///
    /// - Parameters:
    ///   - queuedBitstream: Queued bitstream to check, captured separately to avoid queue position issues.
    ///   - removeFirst: `true` if the first item in the queue should be removed.
    ///
    /// - Returns: block to perform the check.
    func checkBitstreamIsTransmitting(_ queuedBitstream: QueuedBitstream, removeFirst: Bool) -> (() -> Void) {
        return {
            guard self.isRunning else { return }
            guard queuedBitstream.isTransmitting else {
                self.dispatchQueue.asyncAfter(deadline: .now() + Driver.bitstreamCheckInterval, execute: self.checkBitstreamIsTransmitting(queuedBitstream, removeFirst: removeFirst))
                return
            }
            
            if removeFirst {
                self.bitstreamQueue.remove(at: 0)
            }
            
            self.dispatchQueue.asyncAfter(deadline: .now() + .microseconds(Int(queuedBitstream.duration)), execute: self.checkBitstreamIsRepeating(queuedBitstream))
        }
    }
    
    /// Returns block to check whether a bitstream is repeating yet.
    ///
    /// Once a bitstream begins repeating, we call the optional `completionHandler` attached to it.
    ///
    /// This method returns a block that is intended to be run on `dispatchQueue`. The block self-reschedules itself at `bitstreamCheckInterval` while the condition is false.
    ///
    /// - Parameters:
    ///   - queuedBitstream: Queued bitstream to check, captured separately to avoid queue position issues.
    ///
    /// - Returns: block to perform the check.
    func checkBitstreamIsRepeating(_ queuedBitstream: QueuedBitstream) -> (() -> Void) {
        return {
            guard self.isRunning else { return }
            guard queuedBitstream.isRepeating else {
                self.dispatchQueue.asyncAfter(deadline: .now() + Driver.bitstreamCheckInterval, execute: self.checkBitstreamIsRepeating(queuedBitstream))
                return
            }
            
            if let completionHandler = queuedBitstream.completionHandler {
                completionHandler()
            }
        }
    }
    
    /// Interval between watchdog checks.
    static let watchdogInterval: DispatchTimeInterval = .milliseconds(10)

    func watchdog() {
        guard self.isRunning else { return }

        var pwm = raspberryPi.pwm()
        if pwm.status.contains(.busError) {
            // Always seems to be set, and doesn't go away *shrug*
            //print("PWM Bus Error")
            pwm.status.insert(.busError)
        }
        
        if pwm.status.contains(.fifoReadError) {
            print("PWM FIFO Read Error")
            pwm.status.insert(.fifoReadError)
        }
        
        if pwm.status.contains(.fifoWriteError) {
            print("PWM FIFO Write Error")
            pwm.status.insert(.fifoWriteError)
        }
        
        if pwm.status.contains(.channel1GapOccurred) {
            print("PWM Channel 1 Gap Occurred")
            pwm.status.insert(.channel1GapOccurred)
        }
        
        if pwm.status.contains(.fifoEmpty) {
            // Doesn't seem to be an issue, unless maybe we get a gap as above?
            //print("PWM FIFO Empty")
        }
        
        var dma = raspberryPi.dma(channel: Driver.dmaChannel)

        if dma.controlStatus.contains(.errorDetected) {
            print("DMA Error Detected:")
        }
        
        if dma.debug.contains(.readError) {
            print("DMA Read Error")
            dma.debug.insert(.readError)
        }
        
        if dma.debug.contains(.fifoError) {
            print("DMA FIFO Error")
            dma.debug.insert(.fifoError)
        }
        
        if dma.debug.contains(.readLastNotSetError) {
            print("DMA Read Last Not Set Error")
            dma.debug.insert(.readLastNotSetError)
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + Driver.watchdogInterval, execute: watchdog)
    }

}


/// DMA Control Blocks and accompanying Data parsed from a DCC `Bitstream`.
///
/// Initialize with a `Bitstream` to generate the appropriate DMA Control Blocks and Data for use with `Driver`.
///
/// The principle difficulty is that the PWM doesn't immediately begin outputting the word written after a DREQ, which requires that associated GPIO events such as the RailCom cutout and Debug period have to be delayed relative to the words they are intended to accompany. This ultimately requires in some cases that the bitstream loop be partially or even completely unrolled in order to generate a correct repeating output.
struct QueuedBitstream : CustomDebugStringConvertible {
 
    /// Raspberry Pi hardware information.
    let raspberryPi: RaspberryPi
    
    /// Duration in microseconds of the bitstream.
    ///
    /// This is the expected duration between the start and end control blocks, and does not include any loop unrolling that the queued bitstream has performed.
    ///
    /// Copied from the `Bitstream` passed in initialization.
    let duration: Float
    
    /// Size of words.
    ///
    /// Copied from the `Bitstream` passed in initialization.
    let wordSize: Int
    
    /// DMA Control Blocks parsed from the bitstream.
    ///
    /// Since the physical uncached addresses are not yet known, the values of `sourceAddress` are offsets in bytes from the start of the `data` array; and the values of `destinationAddress`, and `nextControlBlockAddress` are offsets in bytes from the start of the `controlBlocks` array if they are below `RaspberryPi.peripheralBusAddress`.
    var controlBlocks: [DMAControlBlock] = []
    
    /// Data parsed from the bitstream.
    ///
    /// The first value is always the flag used by the start and end control blocks and begins as zero.
    var data: [Int] = [ 0 ]

    /// Optional completion handler associated with the bitstream.
    var completionHandler: (() -> Void)?
    
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
        
        duration = bitstream.duration
        wordSize = bitstream.wordSize

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
    
    /// Adjusts the last control block's `nextControlBlockAddress`.
    ///
    /// - Parameters:
    ///   - next: index of control block to change to.
    mutating func setNextControlBlock(_ next: Int) {
        assert(!controlBlocks.isEmpty, "Cannot be called without control blocks.")
        controlBlocks[controlBlocks.count - 1].nextControlBlockAddress = MemoryLayout<DMAControlBlock>.stride * next
    }

    /// Parse a `Bitstream`.
    ///
    /// - Parameters:
    ///   - bitstream: the `Bitstream` to be parsed.
    ///
    /// - Throws:
    ///   `DriverError.bitstreamContainsNoData` if `bitstream` is missing data records, which may include within a repeating section. Recommended recovery is to add preamble bits and try again.
    mutating func parseBitstream(_ bitstream: Bitstream) throws  {
        // Keep track of the current range register value, since we don't know what it was prior to this bitstream beginning, use zero so that the first data event will always set it correctly.
        var range: Int = 0
        
        // Also keep track the set of GPIO events that are being delayed so that they line up with the correct PWM word.
        var delayedEvents = DelayedEvents()

        // For efficiency, we collect multiple consecutive words of data together into a single control block, and only break where necessary. For loop unrolling we track the index within the bitstream that the `words` array began, and the set of delayed events at each of those points.
        var words: [Int] = []
        var wordsIndex = bitstream.endIndex
        var wordsDelayedEvents: [Array.Index: DelayedEvents] = [:]
        
        // As we output control blocks for data, we keep track of the map between index within the bitstream and index within the control blocks array, so we can loop back to them. After we exit the loop, the `loopControlBlockIndex` contains the appropraite control block index for the end control block.
        var controlBlockIndexes: [Array.Index: Int] = [:]
        var loopControlBlockIndex = -1
        
        // Usually we loop through the entire bitstream, but if the bitstream contains a repeating section marker, we only loop through the latter part on subsequent iterations.
        var restartFromIndex = bitstream.startIndex
        
        // Write out the start control block.
        addControlBlockForStart()

        repeat {
            var foundData = false
            var appendEnd = true
            bitstream: for index in bitstream.suffix(from: restartFromIndex).indices {
                let event = bitstream[index]
                switch event {
                case let .data(word: word, size: size):
                    foundData = true
                    
                    // We can only break out of the loop here if this data in the prior iteration had the same set of delayed events that we do now.
                    if let previousDelayedEvents = wordsDelayedEvents[index],
                        previousDelayedEvents == delayedEvents
                    {
                        // Generally we expect that to mean that this data began a control block in the prior iteration, in which case that control block becomes our loop target and we're done.
                        if let previousControlBlockIndex = controlBlockIndexes[index] {
                            loopControlBlockIndex = previousControlBlockIndex
                            appendEnd = false
                            break bitstream
                        }
                        
                        // But it can also mean that we've consumed nothing but data and looped back to ourselves, in which case we just break out knowing we'll write out that data, and set that to be the loop target.
                        if index == wordsIndex {
                            loopControlBlockIndex = controlBlocks.count
                            appendEnd = false
                            break bitstream
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
                    controlBlockIndexes[wordsIndex] = controlBlocks.count
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
                    
                    // If there is pending data, we write it out here; this isn't strictly necessary because it'll happen anyway, but it results in a nice clean data break at the loop point and avoids unnecessary unrolling.
                    if !words.isEmpty {
                        controlBlockIndexes[wordsIndex] = controlBlocks.count
                        addControlBlockForData(words)
                        words.removeAll()
                    }
                }
            }
            
            if !words.isEmpty {
                // Some trailing words in the bitstream need to be written out.
                controlBlockIndexes[wordsIndex] = controlBlocks.count
                addControlBlockForData(words)
                words.removeAll()
            }

            if appendEnd {
                addControlBlockForEnd()
                appendEnd = false
            }
            
            guard foundData else { throw DriverError.bitstreamContainsNoData }
        } while loopControlBlockIndex < 0
        
        setNextControlBlock(loopControlBlockIndex)
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
    
    /// Bus address of the bitstream in memory.
    ///
    /// This address is within the “‘C’ Alias” and may be handed directly to hardware such as the DMA Engine. To obtain an equivalent address outside the alias, remove RaspberryPi.uncachedAliasBusAddress from this value.
    ///
    /// This value is only available once `commit()` has been called.
    var busAddress: Int {
        guard let memory = memory else { fatalError("Queued bitstream has not been committed to uncached memory.") }
        return memory.busAddress
    }

    /// Indicates whether the bitstream is currently transmitting.
    ///
    /// This value is only available once `commit()` has been called.
    var isTransmitting: Bool {
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
    var isRepeating: Bool {
        guard let memory = memory else { fatalError("Queued bitstream has not been committed to uncached memory.") }
        
        let controlBlocksSize = MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
        let uncachedData = memory.pointer.advanced(by: controlBlocksSize).assumingMemoryBound(to: Int.self)
        
        return uncachedData[0] < 0
    }
    
    func transfer(toBusAddress busAddress: Int) {
        guard let memory = memory else { fatalError("Queued bitstream has not been committed to uncached memory.") }

        let uncachedControlBlocks = memory.pointer.assumingMemoryBound(to: DMAControlBlock.self)
        
        uncachedControlBlocks[controlBlocks.count - 1].nextControlBlockAddress = busAddress
    }
    
    /// A textual representation of this instance, suitable for debugging.
    ///
    /// The string is generated by parsing the `controlBlocks` and `data` members.
    var debugDescription: String {
        var description = "QueuedBitstream:\n"
        
        // Adjust the base of the addresses depending on whether commit() has been called or not.
        let controlBlocksBase: Int
        let dataBase: Int
        if let memory = memory {
            controlBlocksBase = memory.busAddress
            dataBase = memory.busAddress + MemoryLayout<DMAControlBlock>.stride * controlBlocks.count
        } else {
            controlBlocksBase = 0
            dataBase = 0
        }
        
        for (index, controlBlock) in controlBlocks.enumerated() {
            let dataIndex = (controlBlock.sourceAddress - dataBase) / MemoryLayout<Int>.stride
            let dataSize = controlBlock.transferLength / MemoryLayout<Int>.stride

            let next = (controlBlock.nextControlBlockAddress - controlBlocksBase) / MemoryLayout<DMAControlBlock>.stride

            switch controlBlock.destinationAddress {
            case dataBase:
                // Start or End.
                switch data[dataIndex] {
                case 1:
                    description += "  \(index): Start → \(next)\n"
                case -1:
                    description += "  \(index): End → \(next)\n"
                default:
                    description += "  \(index): Unknown start/end \(data[dataIndex]) → \(next)\n"
                }
            case raspberryPi.peripheralBusAddress + PWM.offset + PWM.fifoInputOffset:
                // PWM Data.
                description += "  \(index): Data → \(next)\n"
                for i in dataIndex..<(dataIndex + dataSize) {
                    let str = String(UInt(bitPattern: data[i]), radix: 2)
                    let pad = String(repeating: "0", count: wordSize - str.characters.count)
                    description += "    \(pad)\(str)\n"
                }
            case raspberryPi.peripheralBusAddress + PWM.offset + PWM.channel1RangeOffset:
                // PWM Range.
                description += "  \(index): Range \(data[dataIndex]) → \(next)\n"
            case raspberryPi.peripheralBusAddress + GPIO.offset + GPIO.outputSetOffset:
                // GPIO.
                let setField = GPIOBitField(field0: data[dataIndex], field1: data[dataIndex + 1])
                let clearField = GPIOBitField(field0: data[dataIndex + 2], field1: data[dataIndex + 3])
                
                description += "  \(index): GPIO → \(next)\n"
                if setField[Driver.railComGpio] {
                    description += "    ↑ RailCom\n"
                }
                if setField[Driver.debugGpio] {
                    description += "    ↑ Debug\n"
                }

                if clearField[Driver.railComGpio] {
                    description += "    ↓ RailCom\n"
                }
                if clearField[Driver.debugGpio] {
                    description += "    ↓ Debug\n"
                }
            default:
                description += "  \(index): Unknown → \(next)\n"
            }
        }
        
        return description
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
