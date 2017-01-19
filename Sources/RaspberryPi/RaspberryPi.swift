//
//  RaspberryPi.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

#if os(Linux)
import Glibc

// Definition is missing from Glibc, this one taken from Darwin.
let MAP_FAILED = UnsafeMutableRawPointer(bitPattern: -1)! as UnsafeMutableRawPointer!
#else
import Darwin
    
// This is not defined on Darwin. Set to 0 to allow compilation to succeed.
let O_SYNC: Int32 = 0
#endif

import Foundation


/// Raspberry Pi hardware.
///
/// Provides details about the Raspberry Pi hardware, such as memory addresses of peripherals.
public class RaspberryPi {

    /// Size, in bytes, of memory pages.
    public let pageSize = 4096
    
    /// Bus address of I/O Peripherals.
    ///
    /// The bus address is the address utilized for hardware, including the DMA engine.
    public let peripheralBusAddress = 0x7e000000

    /// Bus address of the uncached memory 'C' alias.
    ///
    /// The Raspberry Pi hardware provides an alias to memory addresses that bypasses the L1 and L2 caches, and can be allocated using `allocateUncachedMemory(minimumSize:)`. To translate the `busAddress` of that object into a un-aliased physical address, remove this constant from it; likewise to translate an un-aliased physical address into an aliased bus address, add this constant.
    public let uncachedAliasBusAddress = Int(bitPattern: 0xc0000000)

    /// Bus address of I/O Peripherals on the earlier Pi models.
    let bcm2835Address = 0x20000000
    
    /// Size of the I/O Peripherals address range on the earlier Pi models.
    let bcm2835Size = 0x01000000
    
    /// Address where I/O Peripherals begin.
    ///
    /// This is a physical address suitable for using with `mapMemory(at:size:)`, the value of which varies depending on the specific Raspberry Pi model. For hardware such as the DMA Engine, use the fixed `peripheralBusAddress`.
    public let peripheralAddress: Int
    
    /// Size of the I/O Peripherals range.
    ///
    /// This value varies depending on the specific Raspberry Pi model, and applies equally to `peripheralAddress` and `peripheralBusAddress`.
    public let peripheralSize: Int

    /// Mapped I/O peripherals memory region.
    var peripherals: UnsafeMutableRawPointer!
    
    /// Indicates whether `peripherals` should be unmapped on deinitialization.
    var unmapPeripheralsOnDeinit: Bool = true

    /// Initalize.
    ///
    /// - Throws: `RaspberryPiError` on failure.
    public init() throws {
        if let rangeMap = try? RaspberryPi.loadRanges(),
            let (address, size) = rangeMap[peripheralBusAddress]
        {
            peripheralAddress = address
            peripheralSize = size
        } else {
            peripheralAddress = bcm2835Address
            peripheralSize = bcm2835Size
        }
        
        peripherals = try mapMemory(at: peripheralAddress, size: peripheralSize)
    }
    
    /// Location of the device tree ranges map.
    static let deviceTreeRangesPath = "/proc/device-tree/soc/ranges"

    /// Loads system-specific memory ranges from the device tree.
    ///
    /// Returns: a map from bus address to physical address and size for each mapped area.
    ///
    /// Throws: errors from `Data(contentsOf:)`.
    static func loadRanges() throws -> [Int: (Int, Int)] {
        let ranges = try Data(contentsOf: URL(fileURLWithPath: RaspberryPi.deviceTreeRangesPath))
        return ranges.withUnsafeBytes { (addresses: UnsafePointer<Int>) -> [Int: (Int, Int)] in
            let numberOfAddresses = ranges.count / MemoryLayout<Int>.stride
            var addressMap: [Int: (Int, Int)] = [:]
            
            for i in 0..<(numberOfAddresses / 3) {
                addressMap[addresses[i + 0].byteSwapped] = (addresses[i + 1].byteSwapped, addresses[i + 2].byteSwapped)
            }
            
            return addressMap
        }
    }
    
    /// Initialize for testing.
    ///
    /// - Parameters:
    ///   - peripheralAddress: address where peripherals should be on the real hardware.
    ///   - peripheralAddressSize: size of peripheral memory region on the real hardware.
    init(peripheralAddress: Int, peripheralSize: Int) {
        self.peripheralAddress = peripheralAddress
        self.peripheralSize = peripheralSize
        
        self.peripherals = UnsafeMutableRawPointer.allocate(bytes: peripheralSize, alignedTo: pageSize)
        unmapPeripheralsOnDeinit = false
    }
    
    deinit {
        if let peripherals = peripherals {
            if unmapPeripheralsOnDeinit {
                munmap(peripherals, peripheralSize)
            } else {
                peripherals.deallocate(bytes: peripheralSize, alignedTo: pageSize)
            }
        }
    }
    
    /// Location of the `/dev/mem` device.
    static let memDevicePath = "/dev/mem"
    
    /// File handle for `/dev/mem`.
    ///
    /// This is opened on the first call to `mapMemory(at:size:)` but then cached afterwards.
    var memFileHandle: FileHandle!

    /// Make a memory region accessible via pointer.
    ///
    /// When reading from a datasheet, `address` is the physical address of the region.
    ///
    /// Use `munmap` to release the pointer.
    ///
    /// - Parameters:
    ///   - address: physical address of the memory region.
    ///   - size: size, in bytes, of the memory region.
    ///
    /// - Returns: raw pointer to the local virtual address of the memory region.
    ///
    /// - Throws: `RaspberryPiError` on failure.
    func mapMemory(at address: Int, size: Int) throws -> UnsafeMutableRawPointer {
        if memFileHandle == nil {
            // O_SYNC on Linux provides us with an uncached mmap.
            let memFd = open(RaspberryPi.memDevicePath, O_RDWR | O_SYNC)
            guard memFd >= 0 else {
                switch errno {
                case EACCES:
                    throw RaspberryPiError.permissionDenied
                default:
                    throw RaspberryPiError.systemCallFailed(errno: errno)
                }
            }
            
            memFileHandle = FileHandle(fileDescriptor: memFd, closeOnDealloc: true)
        }
        
        // Since "the zero page" is a valid address to which memory can be mapped, mmap() always returns a pointer.
        // Compare against the special MAP_FAILED value (-1) to determine failure.
        let pointer: UnsafeMutableRawPointer = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, memFileHandle.fileDescriptor, off_t(address))
        guard pointer != MAP_FAILED else {
            throw RaspberryPiError.systemCallFailed(errno: errno)
        }

        return pointer
    }
    
    /// Obtain an object to manipulate a DMA Channel.
    ///
    /// - Parameters:
    ///   - channel; DMA Channel number.
    ///
    /// - Returns: `DMAChannel` object for the channel given.
    public func dma(channel: Int) -> DMAChannel {
        assert(channel >= 0 && channel < DMA.count, "\(channel) is out of range")
        return DMAChannel(channel: channel, peripherals: peripherals)
    }
    
    /// Obtain an object to manipulate a GPIO pin.
    ///
    /// - Parameters:
    ///   - number: GPIO number.
    ///
    /// - Returns: `GPIO` object for the pin given.
    public func gpio(number: Int) -> GPIO {
        assert(number >= 0 && number < GPIO.count, "\(number) is out of range")
        return GPIO(number: number, peripherals: peripherals)
    }
    
    /// Mailbox instance for uncached memory allocation.
    ///
    /// This is opened on the first call to `allocateUncachedMemory` but then cached afterwards.
    var mailbox: Mailbox!
    
    /// Allocate a region of uncached memory.
    ///
    /// Uncached memory is accessed through the Raspberry Pi's "'C' Alias" such that all reads directly come from, and all writes directly go to, RAM bypassing the core's L1 and L2 caches. While such accesses are significantly slower, this allows for interacting with hardware such as the DMA Engine which cannot _see_ these caches.
    ///
    /// The returned object must be retained as long as the region is required, and will release the memory region on deinitialization. In addition, due to the way in which uncached memory is allocated, the memory region is **not** automatically released on process exit. You must deallocate it manually by either releasing the object or calling its `deallocate()` method.
    ///
    /// - Parameters:
    ///   - minimumSize: minimum size, in bytes, of the region. This will be rounded up to the nearest multiple of `pageSize`.
    ///
    /// - Returns: `UncachedMemory` object describing the region.
    ///
    /// - Throws: `MailboxError` or `RaspberryPiError` on failure.
    public func allocateUncachedMemory(minimumSize: Int) throws -> MemoryRegion {
        let size = pageSize * (((minimumSize - 1) / pageSize) + 1)
        
        if mailbox == nil {
            try mailbox = Mailbox()
        }
        let handle = try mailbox.allocateMemory(size: size, alignment: pageSize, flags: .direct)
        
        do {
            let busAddress = try mailbox.lockMemory(handle: handle)
            let pointer = try mapMemory(at: busAddress & ~uncachedAliasBusAddress, size: size)
            
            return UncachedMemory(mailbox: mailbox, handle: handle, pointer: pointer, busAddress: busAddress, size: size)
        } catch {
            try! mailbox.releaseMemory(handle: handle)
            throw error
        }
    }
    
}


/// Region of Memory.
public protocol MemoryRegion {
    
    /// Pointer to the region.
    var pointer: UnsafeMutableRawPointer { get }
    
    /// Bus address of the region.
    var busAddress: Int { get }
    
    /// Size of the region.
    var size: Int { get }
    
}

/// Region of Uncached Memory.
///
/// Uncached memory is accessed through the Raspberry Pi's "'C' Alias" such that all reads directly come from, and all writes directly go to, RAM bypassing the core's L1 and L2 caches. While such accesses are significantly slower, this allows for interacting with hardware such as the DMA Engine which cannot _see_ these caches.
///
/// Instances of this object are created using `RaspberryPi.allocateUncachedMemory(minimumSize:)` and must be retained as long as the region is required. The instance will release the memory region on deinitialization. In addition, due to the way in which uncached memory is allocated, the memory region is **not** automatically released on process exit. You must deallocate it manually by either releasing the object or calling `deallocate()`.
public class UncachedMemory : MemoryRegion {

    /// `Mailbox` instance used to allocate the region, and used to release it.
    let mailbox: Mailbox
    
    /// Mailbox handle for the memory region, used to release it.
    var handle: MailboxMemoryHandle?
    
    /// Pointer to the region.
    public let pointer: UnsafeMutableRawPointer
    
    /// Bus address of the region.
    ///
    /// This address is within the "'C' Alias" and may be handed directly to hardware such as the DMA Engine. To obtain an equivalent address outside the alias, remove `RaspberryPi.uncachedAliasBusAddress` from this value.
    public let busAddress: Int
    
    /// Size of the region, a multiple of `RaspberryPi.pageSize`.
    public let size: Int
    
    init(mailbox: Mailbox, handle: MailboxMemoryHandle, pointer: UnsafeMutableRawPointer, busAddress: Int, size: Int) {
        self.mailbox = mailbox
        self.handle = handle
        self.pointer = pointer
        self.busAddress = busAddress
        self.size = size
    }
    
    /// Release the region.
    ///
    /// This is automatically called on object destruction, but may be called in advance if necessary. Uncached memory regions must be deallocated manually on process exit, otherwise the region will remain allocated.
    ///
    /// Accessing the memory region through `pointer` after calling this method will result in a runtime error.
    ///
    /// - Throws: `MailboxError` or `RaspberryPiError` on failure.
    public func deallocate() throws {
        guard let handle = handle else { return }

        // Release the memory with the mailbox first; since it matters more whether this takes place than the munmap.
        try mailbox.releaseMemory(handle: handle)
        self.handle = nil

        guard munmap(pointer, size) == 0 else { throw RaspberryPiError.systemCallFailed(errno: errno) }
    }

    deinit {
        // There isn't much we can do if we fail to release memory. Fortunately it's one of those operations that also shouldn't ever happen.
        try! deallocate()
    }
    
}

