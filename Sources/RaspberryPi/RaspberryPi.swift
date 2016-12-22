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


public enum RaspberryPiError: Error {
    case failed
    case memoryMapFailed(errno: Int32)
}

/// Raspberry Pi hardware.
///
/// This class wraps the details of the Raspberry Pi hardware, and operations on it, including memory mapping.
public class RaspberryPi {

    /// Size in bytes of memory pages.
    public let pageSize = 4096

    /// Bus address where I/O Peripherals begin.
    ///
    /// The bus address is the address utilized for hardware, including the DMA engine.
    public let peripheralBusBaseAddress = 0x7e000000

    /// Physical address where I/O Peripherals begin on the earlier Pi models.
    let bcm2835PhysicalBaseAddress = 0x20000000
    
    /// Size of the I/O Peripherals address range on the earlier Pi models.
    let bcm2835AddressSize = 0x01000000
    
    /// Physical address where I/O Peripherals begin.
    ///
    /// The physical address is the address at which memory may be mapped from `/dev/mem`.
    public let peripheralPhysicalBaseAddress: Int
    
    /// Size of the I/O Peripherals address range.
    public let peripheralAddressSize: Int

    /// Location of the `/dev/mem` device.
    let memPath = "/dev/mem"
    
    /// File handle for `/dev/mem`.
    let memFileHandle: FileHandle
    
    /// Mailbox instance for GPU memory allocation.
    let mailbox: Mailbox
    
    public init() throws {
        // O_SYNC on Linux provides us with an uncached mmap.
        let memFd = open(memPath, O_RDWR | O_SYNC)
        guard memFd >= 0 else { throw RaspberryPiError.failed }
        memFileHandle = FileHandle(fileDescriptor: memFd, closeOnDealloc: true)
        
        try mailbox = Mailbox()
        
        let rangeMap = try RaspberryPi.loadRanges()
        if let (physicalBaseAddress, addressSize) = rangeMap[peripheralBusBaseAddress] {
            peripheralPhysicalBaseAddress = physicalBaseAddress
            peripheralAddressSize = addressSize
        } else {
            peripheralPhysicalBaseAddress = bcm2835PhysicalBaseAddress
            peripheralAddressSize = bcm2835AddressSize
        }
    }
    
    /// Location of the device tree ranges map.
    static let socRangesPath = "/proc/device-tree/soc/ranges"

    /// Loads system-specific memory ranges from the device tree.
    ///
    /// Returns: a map from bus address to physical address and size for each mapped area.
    static func loadRanges() throws -> [Int: (Int, Int)] {
        let ranges = try Data(contentsOf: URL(fileURLWithPath: socRangesPath))
        return ranges.withUnsafeBytes { (addresses: UnsafePointer<Int>) -> [Int: (Int, Int)] in
            let numberOfAddresses = ranges.count / MemoryLayout<Int>.size
            var addressMap: [Int: (Int, Int)] = [:]
            
            for i in 0..<(numberOfAddresses / 3) {
                addressMap[addresses[i + 0].byteSwapped] = (addresses[i + 1].byteSwapped, addresses[i + 2].byteSwapped)
            }
            
            return addressMap
        }
    }
    
    public func mapPeripheral(at offset: Int, size: Int) throws -> UnsafeMutableRawPointer {
        guard let pointer = mmap(
                nil,
                size,
                PROT_READ | PROT_WRITE,
                MAP_SHARED,
                memFileHandle.fileDescriptor,
                off_t(peripheralPhysicalBaseAddress + offset)),
            pointer != MAP_FAILED
            else { throw RaspberryPiError.memoryMapFailed(errno: errno) }
        return pointer
    }
    
    public func allocateUncachedMemory(pages: Int) throws -> (busAddress: Int, pointer: UnsafeMutableRawPointer) {
        let handle = try mailbox.allocateMemory(size: pageSize * pages, alignment: pageSize, flags: .direct)
        do {
            let busAddress = try mailbox.lockMemory(handle: handle)
            
            guard let pointer = mmap(
                    nil,
                    pageSize * pages,
                    PROT_READ | PROT_WRITE,
                    MAP_SHARED,
                    memFileHandle.fileDescriptor,
                    off_t(physicalAddressOfUncachedMemory(forBusAddress: busAddress))),
                pointer != MAP_FAILED
                else { throw RaspberryPiError.memoryMapFailed(errno: errno) }
            
            return (busAddress, pointer)
        } catch {
            try! mailbox.releaseMemory(handle: handle)
            throw error
        }
    }
    
    let uncachedAliasAddress = Int(bitPattern: 0xc0000000)

    public func physicalAddressOfUncachedMemory(forBusAddress address: Int) -> Int {
        return address & ~uncachedAliasAddress
    }
    
}
