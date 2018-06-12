//
//  DMAControlBlock.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/9/18.
//

/// DMA Control Block.
///
/// Values of this type are used by the DMA engine to control its operation.
///
/// After loading a control block, the DMA engine will transfer `transferLength` bytes from
/// `sourceAddress` to `destinationAddress`. Once this transfer is complete, the control block
/// at `nextControlBlockAddress` is loaded.
///
/// The special `DMAControlBlock.stopAddress` address can be set to complete the transfer and
/// deactivate the DMA engine.
///
/// Additional properties of the transfer are set by `transferInformation` which can be manipulated
/// directly as an `OptionSet` or via properties on `DMAControlBlock`.
///
public struct DMAControlBlock : Equatable, Hashable {
    
    /// Transfer information.
    ///
    /// Controls the specifics of the transfer.
    public var transferInformation: DMATransferInformation
    
    /// Source address.
    ///
    /// Bus address where data is to be transferred from.
    public var sourceAddress: UInt32
    
    /// Destination address.
    ///
    /// Bus address where data is to be transferred to.
    public var destinationAddress: UInt32
    
    /// Transfer length.
    ///
    /// Number of bytes to transfer from `sourceAddress` to `destinationAddress`.
    ///
    /// When `is2D` is `true` this field contains a combination of the `xLength` and `yLength`
    /// properties. Those should be used to manipulate the value.
    ///
    /// On "Lite" DMA channels, the length is limited to 65,536.
    public var transferLength: UInt32
    
    /// Stride.
    ///
    /// When `is2D` is `true` this field contains a combination of the `sourceStride` and
    /// `destinationStride` properties. Those should be use to manipulate the value.
    ///
    /// Otherwise this field is ignored.
    public var stride: UInt32
    
    /// Next control block address.
    ///
    /// Bus address where the next control block to be loaded on completion of this one can be
    /// located.
    ///
    /// Set to the value `DMAControlBlock.stopAddress` if this is the final control block.
    public var nextControlBlockAddress: UInt32

    private var reserved0: UInt32
    private var reserved1: UInt32

    /// Control block address to stop transfer.
    ///
    /// Assign this value to `nextControlBlockAddress` to indicate the final control block in a
    /// transfer.
    public static var stopAddress: UInt32 = 0
    
    public init() {
        transferInformation = DMATransferInformation()
        sourceAddress = 0
        destinationAddress = 0
        transferLength = 0
        stride = 0
        nextControlBlockAddress = 0
        
        reserved0 = 0
        reserved1 = 0
    }
    
    public init(transferInformation: DMATransferInformation, sourceAddress: UInt32, destinationAddress: UInt32, transferLength: UInt32, stride: UInt32, nextControlBlockAddress: UInt32) {
        self.transferInformation = transferInformation
        self.sourceAddress = sourceAddress
        self.destinationAddress = destinationAddress
        self.transferLength = transferLength
        self.stride = stride
        self.nextControlBlockAddress = nextControlBlockAddress
        
        self.reserved0 = 0
        self.reserved1 = 0
    }
    
    /// No wide bursts.
    ///
    /// When `true` the DMA engine will not issue wide writes as two-beat AXI bursts. This is
    /// an inefficient access mode.
    public var noWideBursts: Bool {
        get { return transferInformation.contains(.noWideBursts) }
        set {
            if newValue {
                transferInformation.insert(.noWideBursts)
            } else {
                transferInformation.remove(.noWideBursts)
            }
        }
    }
    
    /// Wait cycles.
    ///
    /// Slows down the DMA engine by adding this number of dummy cycles between each DMA read
    /// or write operation.
    public var waitCycles: Int {
        get { return transferInformation.waitCycles }
        set { transferInformation.waitCycles = newValue }
    }
    
    /// Peripheral mapping.
    ///
    /// Maps a hardware peripheral to the DMA engine.
    ///
    /// Once mapped, the data request (DREQ) signal from the peripheral can be used with
    /// `sourceWaitsForDataRequest` and `destinationWaitsForDataRequest` to perform transfers only
    /// when the peripheral has data to be read or written.
    ///
    /// In addition the peripheral can raise a panic flag, e.g. with `PWMChannel.panicThreshold`,
    /// which is combined with `DMAChannel.panicPriority` to adjust the AXI transfer priorities when
    /// there is an urgency for data.
    public var peripheral: DMAPeripheral {
        get { return transferInformation.peripheral }
        set { transferInformation.peripheral = newValue }
    }

    /// Burst transfer length.
    ///
    /// In the circumstances where the DMA engine can generate a burst (see BCM2835 ARM Peripherals
    /// 4.3), this indicates the length of those bursts in words.
    ///
    /// A value of `0` indicates a single word.
    public var burstTransferLength: Int {
        get { return transferInformation.burstTransferLength }
        set { transferInformation.burstTransferLength = newValue }
    }

    /// Source ignores reads.
    ///
    /// When `true` the DMA engine will not perform reads from `sourceAddress` and will write
    /// zero to the destination.
    ///
    /// This can be used for fast cache fill operations.
    ///
    /// This option is not available on "Lite" DMA channels.
    public var sourceIgnoreReads: Bool {
        get { return transferInformation.contains(.sourceIgnoreReads) }
        set {
            if newValue {
                transferInformation.insert(.sourceIgnoreReads)
            } else {
                transferInformation.remove(.sourceIgnoreReads)
            }
        }
    }
    
    /// Source waits for Data Request.
    ///
    /// When `true` the DMA engine will wait for a DREQ signal from the peripheral before performing
    /// reads from `sourceAddress`.
    public var sourceWaitsForDataRequest: Bool {
        get { return transferInformation.contains(.sourceWaitsForDataRequest) }
        set {
            if newValue {
                transferInformation.insert(.sourceWaitsForDataRequest)
            } else {
                transferInformation.remove(.sourceWaitsForDataRequest)
            }
        }
    }
    
    /// Source performs wide reads.
    ///
    /// When `true` the DMA engine will perform 128-bit width reads from `sourceAddress`; when
    /// `false` the DMA engine performs 32-bit width reads from `sourceAddress`.
    public var sourceWideReads: Bool {
        get { return transferInformation.contains(.sourceWideReads) }
        set {
            if newValue {
                transferInformation.insert(.sourceWideReads)
            } else {
                transferInformation.remove(.sourceWideReads)
            }
        }
    }
    
    /// Source address incremented after reads.
    ///
    /// When `true` the DMA engine will increment `sourceAddress` after each read; the incremented
    /// value is determined by `sourceWideReads`. When `false the DMA engine will read from the
    /// same `sourceAddress` for each read width.
    public var incrementSourceAddress: Bool {
        get { return transferInformation.contains(.incrementSourceAddress) }
        set {
            if newValue {
                transferInformation.insert(.incrementSourceAddress)
            } else {
                transferInformation.remove(.incrementSourceAddress)
            }
        }
    }

    /// Destination ignores writes.
    ///
    /// When `true` the DMA engine will not perform writes to `destinationAddress`.
    ///
    /// This option is not available on "Lite" DMA channels.
    public var destinationIgnoreWrites: Bool {
        get { return transferInformation.contains(.destinationIgnoreWrites) }
        set {
            if newValue {
                transferInformation.insert(.destinationIgnoreWrites)
            } else {
                transferInformation.remove(.destinationIgnoreWrites)
            }
        }
    }
    
    /// Destination waits for Data Request.
    ///
    /// When `true` the DMA engine will wait for a DREQ signal from the peripheral before performing
    /// writes to `destinationAddress`.
    public var destinationWaitsForDataRequest: Bool {
        get { return transferInformation.contains(.destinationWaitsForDataRequest) }
        set {
            if newValue {
                transferInformation.insert(.destinationWaitsForDataRequest)
            } else {
                transferInformation.remove(.destinationWaitsForDataRequest)
            }
        }
    }

    /// Destination performs wide writes.
    ///
    /// When `true` the DMA engine will perform 128-bit width writes to `destinationAddress`; when
    /// `false` the DMA engine performs 32-bit width writes to `destinationAddress`.
    public var destinationWideWrites: Bool {
        get { return transferInformation.contains(.destinationWideWrites) }
        set {
            if newValue {
                transferInformation.insert(.destinationWideWrites)
            } else {
                transferInformation.remove(.destinationWideWrites)
            }
        }
    }

    /// Destination address incremented after writes.
    ///
    /// When `true` the DMA engine will increment `destinationAddress` after each write; the
    /// incremented value is determined by `destinationWideWrites`. When `false the DMA engine will
    /// write to the same `sourceAddress` for each write.
    public var incrementDestinationAddress: Bool {
        get { return transferInformation.contains(.incrementDestinationAddress) }
        set {
            if newValue {
                transferInformation.insert(.incrementDestinationAddress)
            } else {
                transferInformation.remove(.incrementDestinationAddress)
            }
        }
    }
    
    /// Wait for Write Response.
    ///
    /// When `true` the DMA engine will wait for an AXI write response for each write.
    public var waitForWriteResponse: Bool {
        get { return transferInformation.contains(.waitForWriteResponse) }
        set {
            if newValue {
                transferInformation.insert(.waitForWriteResponse)
            } else {
                transferInformation.remove(.waitForWriteResponse)
            }
        }
    }
    
    /// 2D Transfer Mode.
    ///
    /// When 2D transfer mode is selected, the DMA engine will transfer `yLength` transfers of
    /// `xLength` bytes each. After each individual transfer, `sourceAddress` will be incremented
    /// by `sourceStride` and `destinationAddress` will be incremented by `destinationStride`.
    ///
    /// 2D transfer mode is not available on "Lite" DMA channels.
    public var is2D: Bool {
        get { return transferInformation.contains(.tdMode) }
        set {
            if newValue {
                transferInformation.insert(.tdMode)
            } else {
                transferInformation.remove(.tdMode)
            }
        }
    }
    
    /// Raise interrupt on completion.
    ///
    /// If `true` the DMA engine will raise an interrupt when the transfer described by this
    /// control block completes. `DMAChannel.isInterruptRaised` becomes `true` and must be set to
    /// `false` to clear.
    public var raiseInterrupt: Bool {
        get { return transferInformation.contains(.raiseInterrupt) }
        set {
            if newValue {
                transferInformation.insert(.raiseInterrupt)
            } else {
                transferInformation.remove(.raiseInterrupt)
            }
        }
    }
    
    /// Y transfer length.
    ///
    /// When 2D transfer mode is selected, this indicates the number of transfers of `xLength`
    /// bytes each that should be performed.
    ///
    /// When 2D transfer mode is not selected, this returns a bitwise portion of `transferLength`.
    ///
    /// 2D transfer mode is not available on "Lite" DMA channels.
    public var yLength: Int {
        get { return Int((transferLength >> 16) & UInt32.mask(bits: 14)) }
        set {
            assert(newValue >= 0 && newValue < (1 << 14), "length out of range")
            transferLength = transferLength & UInt32.mask(except: 14, offset: 16) | (UInt32(newValue) << 16)
        }
    }
    
    /// X transfer length.
    ///
    /// When 2D transfer mode is selected, this indicates the length of each transfer, repeated
    /// `yLength` times.
    ///
    /// When 2D transfer mode is not selected, this returns a bitwise portion of `transferLength`.
    ///
    /// 2D transfer mode is not available on "Lite" DMA channels.
    public var xLength: Int {
        get { return Int(transferLength & UInt32.mask(bits: 16)) }
        set {
            assert(newValue >= 0 && newValue < (1 << 16), "length out of range")
            transferLength = transferLength & UInt32.mask(except: 16) | UInt32(newValue)
        }
    }
    
    /// Source stride.
    ///
    /// When 2D transfer mode is selected, this indicates the increment to apply to `sourceAddress`
    /// after each `xLength` bytes have been transferred.
    ///
    /// This value may be negative and has the range -32,768 to 32,767.
    ///
    /// 2D transfer mode is not available on "Lite" DMA channels.
    public var sourceStride: Int {
        get {
            // In order to convert the field of arbitrary length while retaining the sign, we shift
            // it all the way to the left, then convert it to a signed Int32 of the same bit pattern,
            // and shift it back to the right again - thus sign-filling it. This gives a value we
            // can convert to a platform-width Int.
            return Int(truncatingIfNeeded: Int32(bitPattern: stride << 16) >> 16)
        }
        set {
            assert(newValue >= -32_768 && newValue <= 32_767, "stride out of range")
            // Since the value is signed, we convert it to UInt32 using the truncatingIfNeeded
            // approach, which retains the sign.
            let field = UInt32(truncatingIfNeeded: newValue) & UInt32.mask(bits: 16)
            stride = stride & UInt32.mask(except: 16) | field
        }
    }
    
    /// Destination stride.
    ///
    /// When 2D transfer mode is selected, this indicates the increment to apply to
    /// `destinationAddress` afer each `xLength` bytes have been transferred.
    ///
    /// This value may be negative and has the range -32,768 to 32,767.
    ///
    /// 2D transfer mode is not available on "Lite" DMA channels.
    public var destinationStride: Int {
        get {
            // Since the field is already left-aligned, to return the sign we first convert it to
            // a signed Int32 of the same bit pattern, and then shift that to the right, this gives
            // us a value we can return as a platform-width Int.
            return Int(truncatingIfNeeded: Int32(bitPattern: stride) >> 16)
        }
        set {
            assert(newValue >= -32_768 && newValue <= 32_767, "stride out of range")
            // Since the value is signed, we convert it to UInt32 using the truncatingIfNeeded
            // approach, which retains the sign.
            let field = UInt32(truncatingIfNeeded: newValue) & UInt32.mask(bits: 16)
            stride = stride & UInt32.mask(except: 16, offset: 16) | (field << 16)
        }
    }

}

// MARK: Debugging

extension DMAControlBlock : CustomDebugStringConvertible {

    public var debugDescription: String {
        var parts: [String] = []

        parts.append("\(type(of: self)) \(transferInformation)")
        parts.append("sourceAddress: \(sourceAddress.hexString)")
        parts.append("destinationAddress:: \(destinationAddress.hexString)")
        if is2D {
            parts.append("yLength: \(yLength)")
            parts.append("xLength: \(xLength)")
            parts.append("sourceStride: \(sourceStride)")
            parts.append("destinationStride: \(destinationStride)")
        } else {
            parts.append("transferLength: \(transferLength)")
            parts.append("stride: \(stride)")
        }
        parts.append("nextControlBlockAddress: \(nextControlBlockAddress.hexString)")

        return "<" + parts.joined(separator: ", ") + ">"
    }

}
