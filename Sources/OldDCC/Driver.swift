//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import Dispatch

import RaspberryPi


/// DMA Driver.
///
/// The driver is responsible for serializing bitstreams and outputting their events as a DCC logic signal and accompanying control signals on the Raspberry Pi's GPIO pins.
///
/// It accomplishes this by using the DMA engine to drive the PWM, feeding data into its FIFO at the rate dictated by the PWM's DREQ signal. Accompanying control signals are generated by using the DMA engine to write to the GPIO registers at the appropriate times. The work of creating the correct control block sequences to accomplish this is handled by the `QueuedBitstream` structure used by this class.
///
/// Individual bitstreams are queued using the `queue(bitstream:)` method, with an optional completion handler that will be run asynchronously once the bitstream has been transmitted at least once. A queued bitstream is repeated until a new bitstream is queued; if a portion of the bitstream should not be repeated, it should be placed first and followed with a `.loopStart` event. If the entire bitstream should onle be transmitted once, it can be queued with the `repeat: false` parameter, in which case it will be followed by a bitstream that cleanly powers down the track.
///
/// When a new bitstream is queued, control is transferred from the currently repeating bitstream, to the new one. By default this transfer only takes place at the end of the bitstream, which for long bitstreams can take some time. If there are earlier points within the bitstream where it would be appropriate and safe to transfer to a new one, these can be denoted by a `.breakpoint` event. Even with breakpoints, a bitstream is always completely transmitted at least once before transfering to a new one.
///
/// A graceful shutdown of the Driver can be performed using the `stop()` method, which will ensure all queued bitstreams are transmitted and the track power cleanly powered down before running its completion handler from where it's safe to call the `shutdown()` method to shutdown the hardware. Calling `shutdown()` at any other time performs an immediate non-graceful shutdown of the hardware which will terminate bitstream transmission abrubtly.
public class Driver {
    
    /// GPIO pin on which to output the DCC logic signal.
    ///
    /// This GPIO is assigned to PWM output, and gives the +3.3V/0V DCC logic signal.
    public static let dccGPIO = 18
    
    /// Alternate function for `dccGPIO` pin to select PWM output.
    public static let dccGPIOFunction = GPIOFunction.alternateFunction5
    
    /// GPIO pin on which to output the RailCom cutout signal.
    ///
    /// This GPIO is assigned to output and doubles as both a power signal and RailCom cutout signal. When high/+3.3V the power should be output to the rails, and when low/0V the rails should be shorted.
    public static let railComGPIO = 17
    
    /// GPIO pin on which to output the Debug signal.
    ///
    /// This GPIO is assigned to output, and will be high/+3.3V for the duration of the DCC logic signal and RailCom cutout period corresponding to an operations mode packet queued with `debug: true`, and is intended for use as an oscilloscope trigger.
    public static let debugGPIO = 19
    
    /// DMA channel to use.
    public static let dmaChannel = 5
    
    /// Clock source to use.
    ///
    /// Either the 19.2MHz `.oscillator` or 500MHz `.plld` are supported.
    public static let clockSource = ClockSource.oscillator

    /// Desired duration in microseconds of a single physical bit.
    ///
    /// On initialization the closest `divisor` to achieve this with `clockSource` is calcuated, and the resulting bit duration placed in `bitDuration`.
    public static let desiredBitDuration: Float = 14.5
    
    /// Duration in microseconds of a single physical bit.
    ///
    /// This should be passed to the `Bitstream` initializer.
    public let bitDuration: Float
    
    /// Integer divisor for the clock.
    let divisor: Int

    /// Number of DREQ signals to delay non-PWM events to synchronize with the PWM output.
    ///
    /// Writing to the PWM FIFO does not immediately result in output, instead the word that we write is first placed into the FIFO, and then next into the PWM's internal queue, before being output. Thus to synchronize an external event, such as a GPIO, with the PWM output we delay it by this many DREQ signals.
    static let eventDelay = 2

    /// Queue of bitstreams.
    ///
    /// The first bitstream in the queue is the one that most recently begun, the last bitstream in the queue is the one that will be repeated.
    ///
    /// - Note: Modifications to this queue must only be made within blocks scheduled on `dispatchQueue`.
    public private(set) var bitstreamQueue: [QueuedBitstream] = []

    /// Dispatch queue for `bitstreamQueue`.
    let dispatchQueue: DispatchQueue

    /// Dispatch group for `dispatchQueue`.
    ///
    /// Items are placed into `dispatchQueue` using `asyncAfter()`, in order to synchronize those on shutdown, items are entered into this dispatch group and removed afterwards.
    let dispatchGroup: DispatchGroup
    
    /// Indicates whether the Driver is currently running.
    public internal(set) var isRunning = false

    /// Initialize the driver.
    ///
    /// The hardware must be initialized before use by calling `startup()`.
    ///
    /// - Parameters:
    ///   - raspberryPi: Raspberry Pi hardware information.
    public init() {
        dispatchQueue = DispatchQueue(label: "com.netsplit.DCC.Driver")
        dispatchGroup = DispatchGroup()
        
        let frequency: Float
        switch Driver.clockSource {
        case .oscillator:
            frequency = 19.2
        case .plld:
            frequency = 500
        default:
            fatalError("Clock source \(Driver.clockSource) is not supported")
        }
        
        divisor = Int(Driver.desiredBitDuration * frequency)
        bitDuration = Float(divisor) / frequency
        
        print("DMA Driver: divisor \(divisor), bit duration \(bitDuration)µs")
    }
    
    /// Initialize hardware.
    ///
    /// Sets up the PWM, GPIO and DMA hardware and prepares for a bitstream to be queued. The DMA Engine will not be activated until the first bitstream is queued with `queue(bitstream:)`.
    public func startup() throws {
        // Disable both PWM channels, and reset the error state.
        let pwm = try PWM()
        pwm.isDMAEnabled = false
        pwm[1].isEnabled = false
        pwm[2].isEnabled = false

        pwm.isBusError = false
        pwm.isFifoReadError = false
        pwm.isFifoWriteError = false
        pwm[1].gapOccurred = false
        pwm[2].gapOccurred = false

        // Clear the FIFO, and ensure neither channel is consuming from it.
        pwm[1].useFifo = false
        pwm[2].useFifo = false
        pwm.clearFifo()

        // Set the PWM clock, using the oscillator as a source. In order to ensure consistent timings, use an integer divisor only.
        let clock = try Clock()
        clock[.pwm].isEnabled = false
        while clock[.pwm].isRunning {}

        clock[.pwm].source = Driver.clockSource
        clock[.pwm].mash = 0
        clock[.pwm].divisor = ClockDivisor(integer: divisor, fractional: 0)

        clock[.pwm].isEnabled = true
        while !clock[.pwm].isRunning {}
        
        // Make sure that the DMA Engine is enabled, abort any existing use of it, and clear error state.
        let dma = try DMA()
        dma[Driver.dmaChannel].isEnabled = true
        dma[Driver.dmaChannel].isActive = false
        dma[Driver.dmaChannel].abort()

        dma[Driver.dmaChannel].reset()
        dma[Driver.dmaChannel].isReadError = false
        dma[Driver.dmaChannel].isFifoError = false
        dma[Driver.dmaChannel].isReadLastNotSetError = false

        // Set the DCC GPIO for PWM output.
        let gpio = try GPIO()
        gpio[Driver.dccGPIO].function = Driver.dccGPIOFunction
        
        // Set the RailCom GPIO for output and clear.
        gpio[Driver.railComGPIO].function = .output
        gpio[Driver.railComGPIO].value = false
        
        // Set the debug GPIO for output and clear.
        gpio[Driver.debugGPIO].function = .output
        gpio[Driver.debugGPIO].value = false
        
        // Enable the PWM, using the FIFO in serializer mode, and DREQ signals sent to the DMA Engine.
        pwm.isDMAEnabled = true
        pwm.dataRequestThreshold = 1
        pwm.panicThreshold = 1
        pwm[1].useFifo = true
        pwm[1].mode = .serializer
        pwm[1].isEnabled = true

        // Set the DMA Engine priority levels.
        dma[Driver.dmaChannel].priorityLevel = 8
        dma[Driver.dmaChannel].panicPriorityLevel = 8

        isRunning = true
        DispatchQueue.global().asyncAfter(deadline: .now() + Driver.watchdogInterval, execute: watchdog)
    }
    
    /// Shutdown hardware.
    ///
    /// Disables the PWM and DMA hardware, and resets the GPIOs to a default state.
    ///
    /// It is essential that this be called before exit, as otherwise the DMA Engine will continue on its programmed sequence and endlessly repeat the last queued bitstream.
    ///
    /// Any currently transmitting bitstream will be terminated abruptly, and any queued bitstreams not transmitted. For a clean shutdown allowing all queued bitstreams to be transmitted once, use `stop()` first and call `shutdown()` in its completion handler, e.g.:
    ///
    ///     try driver.stop {
    ///         driver.shutdown()
    ///     }
    public func shutdown() throws {
        // Disable the PWM channel.
        let pwm = try PWM()
        pwm[1].isEnabled = false
        pwm.isDMAEnabled = false

        // Stop the clock.
        let clock = try Clock()
        clock[.pwm].isEnabled = false

        // Stop the DMA Engine.
        let dma = try DMA()
        dma[Driver.dmaChannel].isActive = false
        dma[Driver.dmaChannel].abort()

        // Clear the bitstream queue to free the uncached memory associated with each bitstream, also cancel any pending tasks and wait for them to ensure blocks aren't holding references as well.
        isRunning = false
        dispatchGroup.wait()
        dispatchQueue.sync() {
            bitstreamQueue.removeAll()
        }
        
        // Restore the DCC GPIO to output, and clear all pins.
        let gpio = try GPIO()
        gpio[Driver.dccGPIO].function = .output
        gpio[Driver.dccGPIO].value = false

        gpio[Driver.railComGPIO].value = false
        
        gpio[Driver.debugGPIO].value = false
    }
    
    /// Interval between watchdog checks.
    static let watchdogInterval: DispatchTimeInterval = .milliseconds(10)
    
    /// Checks for and clears PWM and DMA error states.
    func watchdog() {
        guard isRunning else { return }

        if let pwm = try? PWM() {
            if pwm.isBusError {
                // Always seems to be set, and doesn't go away *shrug*
                //print("PWM Bus Error")
                pwm.isBusError = false
            }

            if pwm.isFifoReadError {
                print("PWM FIFO Read Error")
                pwm.isFifoReadError = false
            }

            if pwm.isFifoWriteError {
                print("PWM FIFO Write Error")
                pwm.isFifoWriteError = false
            }

            if pwm[1].gapOccurred {
                print("PWM Channel 1 Gap Occurred")
                pwm[1].gapOccurred = false
            }

            if pwm.isFifoEmpty {
                // Doesn't seem to be an issue, unless maybe we get a gap as above?
//                print("PWM FIFO Empty")
            }
        }

        if let dma = try? DMA() {
            if dma[Driver.dmaChannel].isErrorDetected {
                print("DMA Error Detected:")
            }

            if dma[Driver.dmaChannel].isReadError {
                print("DMA Read Error")
                dma[Driver.dmaChannel].isReadError = false
            }

            if dma[Driver.dmaChannel].isFifoError {
                print("DMA FIFO Error")
                dma[Driver.dmaChannel].isFifoError = false
            }

            if dma[Driver.dmaChannel].isReadLastNotSetError {
                print("DMA Read Last Not Set Error")
                dma[Driver.dmaChannel].isReadLastNotSetError = false
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + Driver.watchdogInterval, execute: watchdog)
    }

    
    /// Indicates whether the next queued bitstream will require powering on.
    ///
    /// This is set to `false` when a `powerOnBitstream` is queued, and `true` when a `powerOffBitstream` is queued.
    var requiresPowerOn = true
    
    /// Queue bitstream.
    ///
    /// - Parameters:
    ///   - bitstream: DCC Bitstream to be queued.
    ///   - repeating: when `false` the bitstream will not be repeated.
    ///   - completionHandler: Optional block to be run once `bitstream` has been transmitted at least once.
    ///
    /// - Throws:
    ///   Errors from `DriverError`, `MailboxError`, and `RaspberryPiError` on failure.
    public func queue(bitstream: Bitstream, repeating: Bool = true, completionHandler: (() -> Void)? = nil) throws {
        print("Bitstream duration \(bitstream.duration)µs")
        try dispatchQueue.sync {
            let dma = try DMA()
            let dmaActive = dma[Driver.dmaChannel].isActive
            print("DMA \(dmaActive)")

            var activateBitstream: QueuedBitstream? = nil
            if requiresPowerOn {
                print("Requires power on")
                activateBitstream = try queue(bitstream: powerOnBitstream, repeating: false, removePreviousBitstream: !bitstreamQueue.isEmpty, removeThisBitstream: false)
                requiresPowerOn = false
                print("Required power on")
            }
            
            try queue(bitstream: bitstream, repeating: repeating, removePreviousBitstream: true, removeThisBitstream: false, completionHandler: completionHandler)
            print("Queued")

            if !repeating {
                print("Requires power off")
                requiresPowerOn = true
                try queue(bitstream: powerOffBitstream, repeating: false, removePreviousBitstream: true, removeThisBitstream: true)
                print("Required power off")
            }
            
            // Activate the DMA if this is the first bitstream in the queue.
            if !dmaActive {
                print("Activate DMA")
                dma[Driver.dmaChannel].controlBlockAddress = activateBitstream!.busAddress
                dma[Driver.dmaChannel].isActive = true
            }
            print("Done")
        }
    }
    
    /// Queue a single bitstream.
    ///
    /// Internal function used by `queue(bitstream:)` to queue a single bitstream, this must be run on `dispatchQueue`.
    ///
    /// - Parameters:
    ///   - bitstream: bitstream to be queued.
    ///   - repeating: when `false` the bitstream will not be repeated.
    ///   - removePreviousBitstream: when `true` the previous bitstream in the queue should be removed, this should be set for all but the first bitstream in the queue.
    ///   - removeThisBitstream: when `true` this bitstream will be removed from the queue, this should be set for only the last bitstream in the queue and will be ignored if the DMA Channel is still active.
    ///   - completionHandler: Optional block to be run once `bitstream` has been transmitted at least once.
    ///
    /// - Returns: copy of the bitstream queued.
    ///
    /// - Throws:
    ///   Errors from `DriverError`, `MailboxError`, and `RaspberryPiError` on failure.
    @discardableResult
    func queue(bitstream: Bitstream, repeating: Bool, removePreviousBitstream: Bool, removeThisBitstream: Bool, completionHandler: (() -> Void)? = nil) throws -> QueuedBitstream {
        if #available(OSX 10.12, *) {
            dispatchPrecondition(condition: .onQueue(dispatchQueue))
        }

        // Generate the new bitstream based on transferring from the breakpoints of the last one.
        print("Start")
        var queuedBitstream = QueuedBitstream()
        if let previousBitstream = bitstreamQueue.last {
            print("Previous")
            let transferOffsets = try queuedBitstream.transfer(from: previousBitstream, into: bitstream, repeating: repeating)
            print("Transfer from")
            try queuedBitstream.commit()
            print("Committed")
            previousBitstream.transfer(to: queuedBitstream, at: transferOffsets)
            print("Transfer to")
        } else {
            print("new")
            try queuedBitstream.parseBitstream(bitstream, repeating: repeating)
            print("Parsed")
            try queuedBitstream.commit()
            print("Committed")
        }
        
        // Once the new bitstream is transmitting, remove the first one from the queue... strictly speaking this isn't necessarily the one we were transmitting just now, but it doesn't matter as long as this is called the right number of times by all the queued blocks—we'll ultimately end up with just queuedBitstream in the queue.
        whenTransmitting(queuedBitstream) {
            if removePreviousBitstream {
                self.bitstreamQueue.remove(at: 0)
            }
            
            // Wait for the transmission of the bistream to be complete; the extra delay here isn't necessary but it saves on unnecessary repeated checking since we actually know off-hand what the duration should be.
            self.whenRepeating(queuedBitstream, after: .microseconds(Int(bitstream.duration))) {
                if removeThisBitstream {
                    // We only remove ourselves if the DMA Channel has gone inactive; if it's still active, that means our next control block address was changed to point at another bitstream, which will remove us in its own whenTransmitting above.
                    let dma = try! DMA()
                    if !dma[Driver.dmaChannel].isActive {
                        self.bitstreamQueue.remove(at: 0)
                    }
                }
                
                // If there's a completion handler, run it.
                if let completionHandler = completionHandler {
                    DispatchQueue.global().async(execute: completionHandler)
                }
            }
        }

        // Append the bitstream to the queue. This has to come last since it's a value type and we want the queued copy to include the parsing.
        bitstreamQueue.append(queuedBitstream)
        debugPrint(queuedBitstream)
        print()
        
        return queuedBitstream
    }
    
    /// Interval between bitstream state checks.
    ///
    /// We use a repeated dispatch block of this interval, rather than a loop/sleep, to allow interleaving of checks for multiple queued bitstreams.
    static let bitstreamCheckInterval: DispatchTimeInterval = .milliseconds(1)

    /// Executes a block once a queued bitstream is transmitting.
    ///
    /// This must be called on `dispatchQueue`. May execute immediately, otherwise schedules regular checks.
    ///
    /// - Parameters:
    ///   - queuedBitstream: bitstream to wait for transmission to begin.
    ///   - work: block to execute.
    func whenTransmitting(_ queuedBitstream: QueuedBitstream, execute work: @escaping () -> Void) {
        if #available(OSX 10.12, *) {
            dispatchPrecondition(condition: .onQueue(dispatchQueue))
        }

        // Bail out if the Driver is no longer running. Otherwise if the bitstream isn't transmitting yet, schedule another call to ourselves after an interval; continuing the capture of queuedBitstream and self.
        guard isRunning else { return }
        guard queuedBitstream.isTransmitting else {
            dispatchGroup.enter()
            dispatchQueue.asyncAfter(deadline: .now() + Driver.bitstreamCheckInterval) {
                self.whenTransmitting(queuedBitstream, execute: work)
                self.dispatchGroup.leave()
            }
            return
        }
        
        work()
    }
    
    /// Executes a block once a queued bitstream has begun repeating.
    ///
    /// This must be called on `dispatchQueue`. May execute immediately, otherwise schedules a check after `delay`, and then at regular intervals afterwards.
    ///
    /// - Parameters:
    ///   - queuedBitstream: bitstream to wait for transmission to repeat.
    ///   - delay: initial delay to wait if not already repeating, only used for first check.
    ///   - work: block to execute.
    func whenRepeating(_ queuedBitstream: QueuedBitstream, after delay: DispatchTimeInterval = Driver.bitstreamCheckInterval, execute work: @escaping () -> Void) {
        if #available(OSX 10.12, *) {
            dispatchPrecondition(condition: .onQueue(dispatchQueue))
        }

        // Bail out if the Driver is no longer running. Otherwise if the bitstream isn't repeating yet, schedule another call to ourselves after an interval; continuing the capture of queuedBitstream and self.
        guard isRunning else { return }
        guard queuedBitstream.isRepeating else {
            dispatchGroup.enter()
            dispatchQueue.asyncAfter(deadline: .now() + delay) {
                self.whenRepeating(queuedBitstream, execute: work)
                self.dispatchGroup.leave()
            }
            return
        }
        
        work()
    }
    
    /// Returns a bitstream that will power on the tracks and prime the FIFO so that future PWM and GPIO events will be aligned.
    var powerOnBitstream: Bitstream {
        var bitstream = Bitstream(bitDuration: bitDuration)

        for _ in 0..<Driver.eventDelay {
            bitstream.append(.data(word: 0, size: UInt32.bitWidth))
        }

        bitstream.append(.railComCutoutEnd)
        
        return bitstream
    }
    
    /// Returns a bitstream that will power off the tracks and leave the queue in a clean state.
    var powerOffBitstream: Bitstream {
        var bitstream = Bitstream(bitDuration: bitDuration)
        
        bitstream.append(.railComCutoutStart)
        bitstream.append(.debugEnd)
        
        for _ in 0..<Driver.eventDelay {
            bitstream.append(.data(word: 0, size: UInt32.bitWidth))
        }
        
        return bitstream
    }
    
    /// Stop the Driver gracefully.
    ///
    /// The currently transmitting bitstream is completed if not already repeating, and then transferred out at the next breakpoint with delayed events cleared as normal. Both the RailCom and Debug GPIO pins are cleared.
    ///
    /// - Parameters:
    ///   - completionHandler: block to execute once the stop has completed.
    public func stop(completionHandler: @escaping () -> Void) throws {
        try dispatchQueue.sync {
            if requiresPowerOn {
                DispatchQueue.global().async(execute: completionHandler)
            } else {
                requiresPowerOn = true
                try queue(bitstream: powerOffBitstream, repeating: false, removePreviousBitstream: true, removeThisBitstream: true, completionHandler: completionHandler)
            }
        }
    }

}
