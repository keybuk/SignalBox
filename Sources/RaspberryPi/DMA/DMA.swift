//
//  DMA.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 12/21/16.
//

/// DMA (Direct Memory Access) Controller.
///
/// Instances of `DMA` are used to read and manipulate the underlying DMA controller hardware of
/// the Raspberry Pi. All instances manipulate the same hardware, and will differ only in the
/// address of their mapped memory pointer.
///
/// Individual DMA channels are manipulated by subscripting the instance:
///
///     let dma = try DMA()
///     dma[5].controlBlockAddress = address
///     dma[5].isActive = true
///
/// The instance also conforms to `Collection` so can be iterated to address all channels, as well
/// as other collection and sequence behaviors:
///
///     for channel in dma {
///         if channel.isActive {
///             print("\(channel.number) is active")
///         }
///     }
///
public final class DMA : MappedPeripheral, Collection {

    /// Offset of the DMA registers from the peripherals base address.
    ///
    /// - Note: BCM2835 ARM Peripherals 4.2
    public static let offset: UInt32 = 0x007000

    /// Offset of the DMA 15 register from the peripherals base address.
    ///
    /// The registers for the last channel are not contiguous with the rest, so exists on its
    /// own at this offset.
    ///
    /// - Note: BCM2835 ARM Peripherals 4.2
    public static let offset15: UInt32 = 0xe05000

    /// Size of the DMA registers block.
    ///
    /// Unlike other peripherals, DMA channels are not contiguous in memory, and the region
    /// contains other additional registers.
    ///
    /// - Note: BCM2835 ARM Peripherals 4.2
    public static let registerSize: Int = 0x1000
    
    /// Stride between DMA registers.
    ///
    /// Unlike other peripherals, DMA channels are not contiguous in memory. This represents the
    /// stride between one register to another.
    ///
    /// - Note: BCM2835 ARM Peripherals 4.2
    public static let registerStride: Int = 0x100
    
    /// Offset of the interrupt status register within the DMA region.
    public static let interruptStatusOffset: Int = 0xfe0
    
    /// Offset of the enable register within the DMA region.
    public static let enableOffset: Int = 0xff0
    
    /// DMA registers block.
    ///
    /// - Note: BCM2835 ARM Peripherals 4.2
    public struct Registers {
        public var controlStatus: DMAControlStatus
        public var controlBlockAddress: UInt32
        public var transferInformation: DMATransferInformation
        public var sourceAddress: UInt32
        public var destinationAddress: UInt32
        public var transferLength: UInt32
        public var stride: UInt32
        public var nextControlBlockAddress: UInt32
        public var debug: DMADebug

        // For testing.
        internal init() {
            controlStatus = DMAControlStatus()
            controlBlockAddress = 0
            transferInformation = DMATransferInformation()
            sourceAddress = 0
            destinationAddress = 0
            transferLength = 0
            stride = 0
            nextControlBlockAddress = 0
            debug = DMADebug()
        }
    }

    /// Pointers to the mapped DMA registers.
    ///
    /// This is an array of pointers since the registers are not contiguous with in the region.
    public var registers: [UnsafeMutablePointer<Registers>]

    /// Pointer to the mapped interrupt status register.
    public var interruptStatusRegister: UnsafeMutablePointer<DMABitField>

    /// Pointer to the mapped enable register.
    public var enableRegister: UnsafeMutablePointer<DMABitField>

    /// Unmap all registers on deinitialization.
    private var unmapOnDeinit: Bool

    /// Number of DMA registers defined by the Raspberry Pi.
    ///
    /// This is accessible through the instance's `count` member, via `Collection` conformance.
    internal static let count = 16

    public var startIndex: Int { return 0 }
    public var endIndex: Int { return DMA.count }
    public func index(after i: Int) -> Int { return i + 1 }
    public subscript(index: Int) -> DMAChannel { return DMAChannel(dma: self, number: index) }

    public init() throws {
        let memoryDevice = try MemoryDevice()

        let pointer = try memoryDevice.map(address: DMA.address, size: DMA.registerSize)
        let pointer15: UnsafeMutableRawPointer
        do {
            pointer15 = try memoryDevice.map(address: RaspberryPi.periperhalAddress + DMA.offset15, size: DMA.registerStride)
        } catch {
            try! MemoryDevice.unmap(pointer, size: DMA.registerSize)
            throw error
        }

        registers = []
        for i in 0..<(DMA.count - 1) {
            registers.append(pointer.advanced(by: DMA.registerStride * i).bindMemory(to: Registers.self, capacity: 1))
        }
        registers.append(pointer15.bindMemory(to: Registers.self, capacity: 1))

        interruptStatusRegister = pointer.advanced(by: DMA.interruptStatusOffset).bindMemory(to: DMABitField.self, capacity: 1)
        enableRegister = pointer.advanced(by: DMA.enableOffset).bindMemory(to: DMABitField.self, capacity: 1)

        unmapOnDeinit = true
    }

    // For testing.
    internal init(registers: [UnsafeMutablePointer<Registers>], interruptStatusRegister: UnsafeMutablePointer<DMABitField>, enableRegister: UnsafeMutablePointer<DMABitField>) {
        unmapOnDeinit = false
        self.registers = registers
        self.interruptStatusRegister = interruptStatusRegister
        self.enableRegister = enableRegister
    }

    deinit {
        guard unmapOnDeinit else { return }
        let pointers = registers.map({ $0.deinitialize(count: 1) })
        do {
            try MemoryDevice.unmap(pointers.first!, size: DMA.registerSize)
        } catch {
            print("Error on DMA deinitialization: \(error)")
        }
        do {
            try MemoryDevice.unmap(pointers.last!, size: DMA.registerStride)
        } catch {
            print("Error on DMA deinitialization: \(error)")
        }
    }

}
