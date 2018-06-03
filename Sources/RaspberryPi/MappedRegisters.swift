//
//  MappedRegisters.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 5/31/18.
//

#if os(Linux)
import Glibc
#else
import Darwin

// This is not defined on Darwin. Set to 0 to allow compilation to succeed.
public let O_SYNC: Int32 = 0
#endif

import Foundation

/// Location of the physical memory access device.
private let memDevicePath = "/dev/mem"

public protocol MappedRegisters : class {
    
    associatedtype Registers

    /// Offset of the registers from the peripherals base address.
    static var offset: UInt32 { get }
    
    /// Size of the registers memory range.
    static var size: Int { get }
    
    /// Bus address of the registers.
    static var busAddress: UInt32 { get }
    
    /// Physical address of the registers
    static var address: UInt32 { get }
    
    /// Pointer to the mapped registers.
    var registers: UnsafeMutablePointer<Registers> { get set }
    
}

extension MappedRegisters {

    /// Bus address of the registers.
    public static var busAddress: UInt32 {
        return RaspberryPi.peripheralBusAddress + Self.offset
    }
    
    /// Physical address of the registers
    public static var address: UInt32 {
        return RaspberryPi.periperhalAddress + Self.offset
    }

    /// Map the registers to the underlying hardware.
    ///
    /// Use `unmapMemory` to release the pointer.
    ///
    /// - Throws: `OSError` on failure.
    static func mapMemory() throws -> UnsafeMutablePointer<Registers> {
        // O_SYNC on Linux provides us with an uncached mmap.
        let memFd = open(memDevicePath, O_RDWR | O_SYNC)
        guard memFd >= 0 else { throw OSError(errno: errno) }
        defer { close(memFd) }
        
        // Since "the zero page" is a valid address to which memory can be mapped, mmap() always returns a pointer.
        // Compare against the special MAP_FAILED value (-1) to determine failure.
        let pointer = mmap(nil, Self.size, PROT_READ | PROT_WRITE, MAP_SHARED, memFd, off_t(Self.address))!
        guard pointer != MAP_FAILED else { throw OSError(errno: errno) }
        
        return pointer.bindMemory(to: Registers.self, capacity: Self.size / MemoryLayout<Registers>.stride)
    }
    
    /// Unmap the registers from the underlying hardware.
    ///
    /// - Throws: `OSError` on failure.
    static func unmapMemory(of registers: UnsafeMutablePointer<Registers>) throws {
        let count = Self.size / MemoryLayout<Registers>.stride
        let pointer = registers.deinitialize(count: count)
        guard munmap(pointer, Self.size) == 0 else { throw OSError(errno: errno) }
    }

}
