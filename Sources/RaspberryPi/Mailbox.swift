//
//  Mailbox.swift
//  DCC
//
//  Created by Scott James Remnant on 12/21/16.
//

import Foundation

/// Raspberry Pi Mailbox Property interface.
///
/// This class implements the Mailbox Property interface used to communicate to the VideoCore of
/// the Raspberry Pi.
///
/// Only the memory allocation and locking properties are implemented at this time.
///
/// Documentation is available at https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
public final class Mailbox {
    
    /// Location of the `/dev/vcio` device.
    private static let path = "/dev/vcio"
    
    /// File handle for `/dev/vcio`.
    ///
    /// We open this on initialization and retain it for the lifetime of the instance.
    private let fileHandle: FileHandle
    
    /// - Throws: errors from `FileHandle(forReadingFrom:)`.
    public init() throws {
        fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: Mailbox.path))
    }
    
    /// Error codes.
    public enum Error : Swift.Error {
    
        case invalidRequest
        case invalidResponse
        case requestFailed
        
    }
    
    /// Values for property request's code member.
    private static let processRequestCode: UInt32    = 0x00000000
    private static let requestSuccessfulCode: UInt32 = 0x80000000
    private static let parseErrorCode: UInt32        = 0x80000001
    
    /// Bit used to indicate values member was filled by response.
    private static let responseValuesIndicator: UInt32 = 1 << 31
    
    /// Mailbox property ioctl.
    ///
    /// Expansion of `_IOWR(100, 0, char *)` from the Linux kernel headers.
    private static let propertyIoctl = propertyIoctlDir | propertyIoctlSize | propertyIoctlType | propertyIoctlNr
    private static let propertyIoctlDir: UInt = ((1 | 2) << 30)
    private static let propertyIoctlSize: UInt = UInt(MemoryLayout<Int>.stride) << 16
    private static let propertyIoctlType: UInt = 100 << 8
    private static let propertyIoctlNr: UInt = 0 << 0

    /// Property request tags that are currently implemented.
    internal enum PropertyTag: UInt32 {
        case allocateMemory = 0x3000c
        case lockMemory     = 0x3000d
        case unlockMemory   = 0x3000e
        case releaseMemory  = 0x3000f
    }

    /// Make a property request.
    ///
    /// - Parameters:
    ///   - tag: mailbox property tag to request.
    ///   - values: request values for the tag.
    ///
    /// - Returns: array of response values.
    ///
    /// - Throws: `OSError` or `Error` on failure.
    internal func propertyRequest(forTag tag: PropertyTag, values: [UInt32]) throws -> [UInt32] {
        let bufferSize = 6 + values.count
        var buffer: [UInt32] = Array(repeating: 0, count: bufferSize)
        
        buffer[0] = UInt32(MemoryLayout<UInt32>.stride * bufferSize)
        buffer[1] = Mailbox.processRequestCode
        buffer[2] = tag.rawValue
        buffer[3] = UInt32(MemoryLayout<UInt32>.stride * values.count)
        buffer[4] = UInt32(MemoryLayout<UInt32>.stride * values.count)
        
        buffer.replaceSubrange(5..<(5 + values.count), with: values)
        buffer[5 + values.count] = 0

        let result = buffer.withUnsafeMutableBytes {
            ioctl(fileHandle.fileDescriptor, Mailbox.propertyIoctl, $0.baseAddress!)
        }
        guard result == 0 else { throw OSError(errno: errno) }
        
        switch buffer[1] {
        case Mailbox.requestSuccessfulCode:
            guard buffer[4] & Mailbox.responseValuesIndicator != 0 else {
                throw Error.invalidResponse
            }
            
            let numberOfValues = Int(buffer[4] & ~Mailbox.responseValuesIndicator) / MemoryLayout<UInt32>.stride
            return Array(buffer[5..<(5 + numberOfValues)])
        case Mailbox.parseErrorCode:
            throw Error.invalidRequest
        default:
            throw Error.invalidResponse
        }
    }
    
    /// Handle to memory on the GPU.
    public typealias MemoryHandle = UInt32

    /// Flags for `Mailbox.allocateMemory(size:alignment:flags)`
    public struct AllocateMemoryFlags: OptionSet {
        
        public let rawValue: UInt32
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        /// Can be resized to 0 at any time. Use for cached data.
        public static let discardable   = AllocateMemoryFlags(rawValue: 1 << 0)
        
        /// Normal allocating alias. Don't use from ARM.
        public static let normal        = AllocateMemoryFlags(rawValue: 0 << 2)
        
        /// 0xC alias.  Uncached.
        public static let direct        = AllocateMemoryFlags(rawValue: 1 << 2)
        
        /// 0x8 alias.  Non-allocating in L2 but coherent.
        public static let coherent      = AllocateMemoryFlags(rawValue: 2 << 2)
        
        /// Initialize buffer to all zeros.
        public static let zero          = AllocateMemoryFlags(rawValue: 1 << 4)
        
        /// Don't initialize (default is to initialize to all ones.)
        public static let noInit        = AllocateMemoryFlags(rawValue: 1 << 5)
        
        /// Likely to be locked for long periods of time.
        public static let hintPermalock = AllocateMemoryFlags(rawValue: 1 << 6)
        
        /// Allocating in L2.
        public static let l1Nonallocating: AllocateMemoryFlags = [ .direct, .coherent ]
        
    }
    
    /// Allocate contiguous memory on the GPU.
    ///
    /// Memory must be locked with `lockMemory(handle:)` before it can be accessed.
    ///
    /// The returned handle is not managed by the Linux kernel and will not be automatically freed
    /// on program exit.
    ///
    /// - Parameters:
    ///   - size: number of bytes to allocate.
    ///   - alignment: alignment of returned allocation.
    ///   - flags: `AllocateMemoryFlags`
    ///
    /// - Returns: `MemoryHandle` for allocated memory.
    ///
    /// - Throws: `OSError` or `Error` on failure.
    public func allocateMemory(size: Int, alignment: Int, flags: AllocateMemoryFlags) throws -> MemoryHandle {
        let response = try propertyRequest(forTag: .allocateMemory, values: [ UInt32(size), UInt32(alignment), flags.rawValue ])
        guard response.count == 1 else { throw Error.invalidResponse }
        
        return response[0]
    }
    
    /// Lock memory in place.
    ///
    /// The memory can be accessed through `mmap`.
    ///
    /// - Parameters:
    ///   - handle: `MemoryHandle` to be locked.
    ///
    /// - Returns: bus address of memory.
    ///
    /// - Throws: `OSError` or `Error` on failure.
    public func lockMemory(handle: MemoryHandle) throws -> UInt32 {
        let response = try propertyRequest(forTag: .lockMemory, values: [ handle ])
        guard response.count == 1 else { throw Error.invalidResponse }
        
        return response[0]
    }
    
    /// Unlock memory.
    ///
    /// The memory will retain its contents, but may move.
    ///
    /// - Parameters:
    ///   - handle: `MemoryHandle` to be unlocked.
    ///
    /// - Throws: `OSError` or `Error` on failure.
    public func unlockMemory(handle: MemoryHandle) throws {
        let response = try propertyRequest(forTag: .unlockMemory, values: [ handle ])
        guard response.count == 1 else { throw Error.invalidResponse }
        guard response[0] == 0 else { throw Error.requestFailed }
    }
    
    /// Release memory.
    ///
    /// - Parameters:
    ///   - handle: `MemoryHandle` to be released.
    ///
    /// - Throws: `OSError` or `Error` on failure.
    public func releaseMemory(handle: MemoryHandle) throws {
        let response = try propertyRequest(forTag: .releaseMemory, values: [ handle ])
        guard response.count == 1 else { throw Error.invalidResponse }
        guard response[0] == 0 else { throw Error.requestFailed }
    }
    
}
