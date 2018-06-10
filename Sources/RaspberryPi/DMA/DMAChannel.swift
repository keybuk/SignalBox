//
//  DMAChannel.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/9/18.
//

/// DMA Channel
///
/// Instances of this class are vended by `DMA` and combine the reference to the vending `dma`
/// instance with the channel `number`.
public final class DMAChannel {
    
    public let dma: DMA
    public let number: Int
    
    internal init(dma: DMA, number: Int) {
        self.dma = dma
        self.number = number
    }
    
    /// Pointer to registers for this specific channel.
    private var registers: UnsafeMutablePointer<DMA.Registers> {
        return dma.registers[number]
    }
    
    /// Channel is enabled.
    ///
    /// The DMA controller allows channels to be disabled to save power.
    ///
    /// An enabled channel is not necessarily in use, see `isActive`.
    public var isEnabled: Bool {
        get { return dma.enableRegister.pointee[number] }
        set { dma.enableRegister.pointee[number] = newValue }
    }
    
    /// ??? I don't know what this register does.
    public var interruptStatus: Bool {
        get { return dma.interruptStatusRegister.pointee[number] }
    }
    
    /// Reset the DMA channel.
    public func reset() {
        registers.pointee.controlStatus.insert(.reset)
    }
    
    /// Abort the current control block.
    ///
    /// The current transfer will be aborted, and the next control block loaded and the DMA
    /// channel will attempt to continue.
    public func abort() {
        registers.pointee.controlStatus.insert(.abort)
    }
    
    /// Channel ignores debug pause signal.
    ///
    /// When `true` the DMA channel will not stop when the debug pause signal is asserted.
    public var disableDebugPause: Bool {
        get { return registers.pointee.controlStatus.contains(.disableDebugPause) }
        set {
            if newValue {
                registers.pointee.controlStatus.insert(.disableDebugPause)
            } else {
                registers.pointee.controlStatus.remove(.disableDebugPause)
            }
        }
    }
    
    /// Channel will wait for outstanding writes.
    ///
    /// When `true` the DMA channel will wait at the end of the current transfer for all outstanding
    /// writes before processing the next control block. Also causes the DMA channel to pause on
    /// longer writes than the controller can write.
    ///
    /// While waiting `isWaitingForOutstandingWrites` will be `true`.
    public var waitForOutstandingWrites: Bool {
        get { return registers.pointee.controlStatus.contains(.waitForOutstandingWrites) }
        set {
            if newValue {
                registers.pointee.controlStatus.insert(.waitForOutstandingWrites)
            } else {
                registers.pointee.controlStatus.remove(.waitForOutstandingWrites)
            }
        }
    }
    
    /// Panic priority level.
    ///
    /// Sets the priority of panicking AXI bus transactions, this is combined with the peripheral
    /// configuration (e.g. `PWM.panicThreshold`) and sets the priority of transactions where
    /// 0 is the lowest and 15 is the highest.
    public var panicPriorityLevel: Int {
        get { return registers.pointee.controlStatus.panicPriorityLevel }
        set { registers.pointee.controlStatus.panicPriorityLevel = newValue }
    }
    
    /// Priority level.
    ///
    /// Sets the priority of normal AXI bus transactions where 0 is the lowest and 15 is the
    /// highest.
    public var priorityLevel: Int {
        get { return registers.pointee.controlStatus.priorityLevel }
        set { registers.pointee.controlStatus.priorityLevel = newValue }
    }
    
    /// Channel has detected an error.
    ///
    /// See `isReadError`, `isFifoError`, and `isReadLastNotSetError` for the error detected.
    public var isErrorDetected: Bool {
        return registers.pointee.controlStatus.contains(.errorDetected)
    }
    
    /// Channel is waiting for outstanding writes.
    public var isWaitingForOutstandingWrites: Bool {
        return registers.pointee.controlStatus.contains(.waitingForOutstandingWrites)
    }
    
    /// Channel is paused waiting for DREQ.
    ///
    /// Returns `true` is the channel is active, but currently paused waiting for the DREQ signal
    /// from the peripheral.
    public var isPausedByDataRequest: Bool {
        return registers.pointee.controlStatus.contains(.pausedByDataRequest)
    }

    /// Channel is paused.
    ///
    /// Returns `true` is the channel is paused due to being inactive, executing wait cycles, the
    /// number of outstanding writes has been exceeded the maximum, or if `debugPauseDisabled` is
    /// `false` and the debug pause signal has been raised.
    public var isPaused: Bool {
        return registers.pointee.controlStatus.contains(.paused)
    }
    
    /// Peripheral is requesting data.
    ///
    /// Returns `true` when the peripheral DREQ (Data Request) signal is active, meaning that
    /// data is request.
    public var isRequestingData: Bool {
        return registers.pointee.controlStatus.contains(.requestingData)
    }
    
    /// Channel interrupt status.
    ///
    /// Returns `true` when a transfer with `enableInterrupt` set in the control block ends.
    /// Flag must be cleared by setting to `false`.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isInterruptRaised: Bool {
        get { return registers.pointee.controlStatus.contains(.interruptRaised) }
        set {
            if !newValue {
                registers.pointee.controlStatus.insert(.interruptRaised)
            }
        }
    }
    
    /// Transfer is complete.
    ///
    /// Returns `true` when the transfer is complete. Flag must be cleared by setting to `false`.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    public var isComplete: Bool {
        get { return registers.pointee.controlStatus.contains(.complete) }
        set {
            if !newValue {
                registers.pointee.controlStatus.insert(.complete)
            }
        }
    }
    
    /// Channel is active.
    ///
    /// Set to `true` to active the channel and begin or resume the transfer. Setting to `false`
    /// will pause the currently active transfer, if any. Returns `false` once the transfer is
    /// complete, when `isComplete` will also return true.
    public var isActive: Bool {
        get { return registers.pointee.controlStatus.contains(.active) }
        set {
            if newValue {
                registers.pointee.controlStatus.insert(.active)
            } else {
                registers.pointee.controlStatus.remove(.active)
            }
        }
    }
    
    /// Control block address.
    ///
    /// Address of the control block of the current transfer.
    ///
    /// To initiate a transfer set this to the address of the initial block, and then set
    /// `isActive` to `true`.
    ///
    /// The address must be 256-bit aligned, and must be in the form of a bus address accessible
    /// to the DMA controller; not a physical memory address.
    public var controlBlockAddress: UInt32 {
        get { return registers.pointee.controlBlockAddress }
        set {
            assert(controlBlockAddress & UInt32.mask(bits: 5) == 0, "address has invalid alignment")
            registers.pointee.controlBlockAddress = newValue
        }
    }
    
    /// Current control block.
    ///
    /// Copy of control block currently being transferred, or `nil` if there is no active control
    /// block.
    public var controlBlock: DMAControlBlock? {
        // Take a copy of the registers so we have a single(ish) state.
        let registers = self.registers.pointee
        guard registers.controlBlockAddress != 0 else { return nil }

        return DMAControlBlock(transferInformation: registers.transferInformation,
                               sourceAddress: registers.sourceAddress,
                               destinationAddress: registers.destinationAddress,
                               transferLength: registers.transferLength,
                               stride: registers.stride,
                               nextControlBlockAddress: registers.nextControlBlockAddress)
    }

    /// DMA is reduced performance "LITE" engine.
    public var isLite: Bool {
        return registers.pointee.debug.contains(.isLite)
    }
    
    /// DMA version number.
    public var version: Int {
        return registers.pointee.debug.version
    }
    
    /// DMA engine state machine's state.
    public var stateMachineState: Int {
        return registers.pointee.debug.stateMachineState
    }
    
    /// AXI identifier for this DMA channel.
    public var axiIdentifier: Int {
        return registers.pointee.debug.axiIdentifier
    }
    
    /// Number of outstanding writes.
    public var numberOfOutstandingWrites: Int {
        return registers.pointee.debug.numberOfOutstandingWrites
    }
    
    /// Read error.
    ///
    /// Returns `true` when an error occurs on the read response bus. Flag must be cleared by
    /// setting to `false`.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    var isReadError: Bool {
        get { return registers.pointee.debug.contains(.readError) }
        set {
            if !newValue {
                registers.pointee.debug.insert(.readError)
            }
        }
    }
    
    /// Fifo error.
    ///
    /// Returns `true` when an error occurs on the fifo. Flag must be cleared by setting to `false`.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    var isFifoError: Bool {
        get { return registers.pointee.debug.contains(.fifoError) }
        set {
            if !newValue {
                registers.pointee.debug.insert(.fifoError)
            }
        }
    }

    /// Read last not set error.
    ///
    /// Returns `true` when the AXI read last signal was not set when expected. Flag must be
    /// cleared by setting to `false`.
    ///
    /// - Note:
    ///   Setting the value to false actually writes 1 to the underlying bit; the interface is
    ///   intended to be more programatic than the underlying hardware register.
    var isReadLastNotSetError: Bool {
        get { return registers.pointee.debug.contains(.readLastNotSetError) }
        set {
            if !newValue {
                registers.pointee.debug.insert(.readLastNotSetError)
            }
        }
    }

}

// MARK: Debugging

extension DMAChannel : CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var parts: [String] = []
        
        let register = dma.registers[number].pointee
        parts.append("\(type(of: self)) \(number) \(isEnabled ? "enabled" : "disabled") \(register.controlStatus)")
        if let controlBlock = controlBlock {
            parts.append("controlBlock: \(String(register.controlBlockAddress, radix: 16)) \(controlBlock)")
        }
        parts.append("debug: \(register.debug)")
        
        return "<" + parts.joined(separator: ", ") + ">"
        
    }
    
}
