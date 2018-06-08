//
//  MemoryDevice.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 5/31/18.
//

#if os(Linux)
import Glibc

// This is not defined on Linux.
public let PAGE_SIZE: Int32 = 4096
public let PAGE_SHIFT: Int32 = 12
#else
import Darwin

// This is not defined on Darwin. Set to 0 to allow compilation to succeed.
public let O_SYNC: Int32 = 0
#endif

/// Type permitting mapping of hardware registers.
///
/// Hardware access on the RaspberryPi is handled through registers at specific memory addresses,
/// mapped and unmapped through the `/dev/mem` device.
public final class MemoryDevice {

    internal static let path = "/dev/mem"

    internal let fileDescriptor: Int32

    public init() throws {
        // O_SYNC on Linux provides us with an uncached mmap.
        fileDescriptor = open(MemoryDevice.path, O_RDWR | O_SYNC)
        guard fileDescriptor >= 0 else { throw OSError(errno: errno) }
    }

    deinit {
        close(fileDescriptor)
    }

    /// Map a region to the underlying hardware.
    ///
    /// Use `unmapMemory` to release the pointer.
    ///
    /// - Parameters:
    ///   - address: address to be mapped, must be page aligned.
    ///   - size: size of region.
    ///
    /// - Throws: `OSError` on failure.
    public func map(address: UInt32, size: Int) throws -> UnsafeMutableRawPointer {
        assert(address & UInt32.mask(bits: Int(clamping: PAGE_SHIFT)) == 0, "address must be page-aligned")
        let pointer = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fileDescriptor, off_t(address))!
        guard pointer != MAP_FAILED else { throw OSError(errno: errno) }
        return pointer
    }

    /// Map objects to the underlying hardware.
    ///
    /// Use `unmapMemory` to release the pointer.
    ///
    /// - Parameters:
    ///   - address: address to be mapped, must be page aligned.
    ///   - count: numnber of objects to map.
    ///
    /// - Throws: `OSError` on failure.
    public func map<T>(address: UInt32, count: Int = 1) throws -> UnsafeMutablePointer<T> {
        let pointer = try map(address: address, size: MemoryLayout<T>.stride * count)
        return pointer.bindMemory(to: T.self, capacity: count)
    }

    /// Unmap a region from the underlying hardware.
    ///
    /// - Parameters:
    ///   - pointer: pointer to be unmapped.
    ///   - size: size of mapped region.
    ///
    /// - Throws: `OSError` on failure.
    public static func unmap(_ pointer: UnsafeMutableRawPointer, size: Int) throws {
        guard munmap(pointer, size) == 0 else { throw OSError(errno: errno) }
    }

    /// Unmap mapped objects from the underlying hardware.
    ///
    /// - Parameters:
    ///   - object: objects to be unmapped.
    ///   - count: number of objects mapped.
    ///
    /// - Throws: `OSError` on failure.
    public static func unmap<T>(_ object: UnsafeMutablePointer<T>, count: Int = 1) throws {
        let pointer = object.deinitialize(count: count)
        try unmap(pointer, size: MemoryLayout<T>.stride * count)
    }

}
