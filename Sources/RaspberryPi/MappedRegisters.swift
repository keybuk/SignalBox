//
//  MappedRegisters.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 5/31/18.
//

#if os(Linux)
import Glibc

// This is not defined on Linux.
let PAGE_SIZE = 4096
#else
import Darwin

// This is not defined on Darwin. Set to 0 to allow compilation to succeed.
public let O_SYNC: Int32 = 0
#endif

/// Location of the physical memory access device.
private let memDevicePath = "/dev/mem"

/// Type mapping hardware registers.
///
/// Hardware access on the RaspberryPi is handled through registers at specific memory addresses.
/// Classes handling such hardware should conform to this protocol, and by doing so, they gain
/// implementations of `mapMemory(at:)` and `unnmapMemory(of:)` methods to handle the lifting.
///
///     final class Example : MappedRegisters {
///         struct Registers {
///             var someRegister: UInt32
///             var otherRegister: UInt32
///         }
///         var registers: UnsafeMutablePointer<Registers>
///
///         let offset = 0x...
///
///         init() throws {
///             try mapMemory()
///         }
///
///         deinit {
///             try! unmapMemory()
///         }
///     }
///
public protocol MappedRegisters : class {
    
    associatedtype Registers

    /// Offset of the registers from the peripherals base address.
    var offset: UInt32 { get }
    
    /// Bus address of the registers.
    var busAddress: UInt32 { get }
    
    /// Physical address of the registers
    var address: UInt32 { get }
    
    /// Pointer to the mapped registers.
    var registers: UnsafeMutablePointer<Registers>! { get set }
    
}

extension MappedRegisters {

    /// Bus address of the registers.
    public var busAddress: UInt32 {
        return RaspberryPi.peripheralBusAddress + offset
    }
    
    /// Physical address of the registers
    public var address: UInt32 {
        return RaspberryPi.periperhalAddress + offset
    }

    /// The nearest page boundary below `address`
    var mappableAddress: UInt32 {
        return address & ~(UInt32(clamping: PAGE_SIZE) - 1)
    }

    /// Offset of `address` from `mappableAddress`.
    var mapOffset: Int {
        return Int(clamping: address - mappableAddress)
    }

    /// The multiple of pages required to fit `Registers` and `offset`.
    var mappableSize: Int {
        return ((mapOffset + MemoryLayout<Registers>.stride - 1) / Int(clamping: PAGE_SIZE) + 1) * Int(clamping: PAGE_SIZE)
    }

    /// Map the registers to the underlying hardware.
    ///
    /// Registers are mapped from the nearest page boundary to `address`, and the offsets handled
    /// internally.
    ///
    /// Use `unmapMemory` to release the pointer.
    ///
    /// - Throws: `OSError` on failure.
    func mapMemory() throws {
        // O_SYNC on Linux provides us with an uncached mmap.
        let memFd = open(memDevicePath, O_RDWR | O_SYNC)
        guard memFd >= 0 else { throw OSError(errno: errno) }
        defer { close(memFd) }
        
        // Since "the zero page" is a valid address to which memory can be mapped, mmap() always returns a pointer.
        // Compare against the special MAP_FAILED value (-1) to determine failure.
        let pointer = mmap(nil, mappableSize, PROT_READ | PROT_WRITE, MAP_SHARED, memFd, off_t(mappableAddress))!
        guard pointer != MAP_FAILED else { throw OSError(errno: errno) }
        registers = pointer.advanced(by: mapOffset).bindMemory(to: Registers.self, capacity: 1)
    }
    
    /// Unmap the registers from the underlying hardware.
    ///
    /// - Throws: `OSError` on failure.
    func unmapMemory() throws {
        let pointer = registers.deinitialize(count: 1).advanced(by: -mapOffset)
        guard munmap(pointer, mappableSize) == 0 else { throw OSError(errno: errno) }
        registers = nil
    }

}
