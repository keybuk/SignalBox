//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/30/16.
//
//

import Dispatch

import RaspberryPi


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
    public private(set) var bitstreamQueue: [QueuedBitstream] = []

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
