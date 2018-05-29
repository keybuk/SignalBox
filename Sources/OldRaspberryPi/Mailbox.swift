//
//  Mailbox.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/21/16.
//
//

import Foundation


/// Handle to memory on the GPU.
public typealias MailboxMemoryHandle = UInt32


/// Raspberry Pi Mailbox Property interface.
///
/// This class implements the Mailbox Property interface used to communicate to the VideoCore of the Raspberry Pi.
///
/// Only the memory allocation and locking properties are implemented at this time.
///
/// Documentation is available at https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
public struct Mailbox {
    
    /// Location of the `/dev/vcio` device.
    static let devicePath = "/dev/vcio"
    
    /// File handle for `/dev/vcio`.
    ///
    /// We open this on initialization and retain it for the lifetime of the instance.
    let fileHandle: FileHandle
    
    /// - Throws: errors from `FileHandle(forReadingFrom:)`.
    public init() throws {
        fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: Mailbox.devicePath))
    }
    
    
    /// Values for property request's code member.
    static let processRequestCode: UInt32    = 0x00000000
    static let requestSuccessfulCode: UInt32 = 0x80000000
    static let parseErrorCode: UInt32        = 0x80000001
    
    /// Bit used to indicate values member was filled by response.
    static let responseValuesIndicator: UInt32 = 1 << 31

    /// Mailbox property ioctl.
    ///
    /// Expansion of `_IOWR(100, 0, char *)` from the Linux kernel headers.
    static let mailboxPropertyIoctl: UInt = ((1 | 2) << 30) | (100 << 8)/* | (0 << 0)*/ | (4 << 16)
    
    /// Make a property request.
    ///
    /// - Parameters:
    ///   - tag: mailbox property tag to request.
    ///   - values: request values for the tag.
    ///
    /// - Returns: array of response values.
    ///
    /// - Throws: `RaspberryPiError` on failure.
    func propertyRequest(forTag tag: MailboxPropertyTag, values: [UInt32]) throws -> [UInt32] {
        let bufferSize = 6 + values.count
        var buffer: [UInt32] = Array(repeating: 0, count: bufferSize)
        
        buffer[0] = UInt32(MemoryLayout<UInt32>.stride * bufferSize)
        buffer[1] = Mailbox.processRequestCode
        buffer[2] = tag.rawValue
        buffer[3] = UInt32(MemoryLayout<UInt32>.stride * values.count)
        buffer[4] = UInt32(MemoryLayout<UInt32>.stride * values.count)

        buffer.replaceSubrange(5..<(5 + values.count), with: values)
        buffer[5 + values.count] = 0
        
        let result = ioctl(fileHandle.fileDescriptor, Mailbox.mailboxPropertyIoctl, UnsafeMutableRawPointer(mutating: buffer))
        if result < 0 {
            if errno == EINVAL {
                throw RaspberryPiError.invalidMailboxRequest
            } else {
                throw RaspberryPiError.systemCallFailed(errno: errno)
            }
        }

        switch buffer[1] {
        case Mailbox.requestSuccessfulCode:
            guard buffer[4] & Mailbox.responseValuesIndicator != 0 else {
                throw RaspberryPiError.invalidMailboxResponse
            }
            
            let numberOfValues = Int(buffer[4] & ~Mailbox.responseValuesIndicator) / MemoryLayout<UInt32>.stride
            return Array(buffer[5..<(5 + numberOfValues)])
        case Mailbox.parseErrorCode:
            throw RaspberryPiError.invalidMailboxRequest
        default:
            throw RaspberryPiError.invalidMailboxResponse
        }
    }
    
    /// Allocate contiguous memory on the GPU.
    ///
    /// Memory must be locked with `lockMemory(handle:)` before it can be accessed.
    ///
    /// The returned handle is not managed by the Linux kernel and will not be automatically freed on program exit.
    ///
    /// - Parameters:
    ///   - size: number of bytes to allocate.
    ///   - alignment: alignment of returned allocation.
    ///   - flags: `AllocateMemoryFlags`
    ///
    /// - Returns: `MailboxMemoryHandle` for allocated memory.
    ///
    /// - Throws: `RaspberryPiError` on failure.
    public func allocateMemory(size: Int, alignment: Int, flags: MailboxAllocateMemoryFlags) throws -> MailboxMemoryHandle {
        let response = try propertyRequest(forTag: .allocateMemory, values: [ UInt32(size), UInt32(alignment), flags.rawValue ])
        guard response.count == 1 else { throw RaspberryPiError.invalidMailboxResponse }
        
        return response[0]
    }
    
    /// Lock memory in place.
    ///
    /// The memory can be accessed through `mmap`.
    ///
    /// - Parameters:
    ///   - handle: `MailboxMemoryHandle` to be locked.
    ///
    /// - Returns: bus address of memory.
    ///
    /// - Throws: `RaspberryPiError` on failure.
    public func lockMemory(handle: MailboxMemoryHandle) throws -> Int {
        let response = try propertyRequest(forTag: .lockMemory, values: [ handle ])
        guard response.count == 1 else { throw RaspberryPiError.invalidMailboxResponse }

        return Int(bitPattern: UInt(response[0]))
    }
    
    /// Unlock memory.
    ///
    /// The memory will retain its contents, but may move.
    ///
    /// - Parameters:
    ///   - handle: `MailboxMemoryHandle` to be unlocked.
    ///
    /// - Throws: `RaspberryPiError` on failure.
    public func unlockMemory(handle: MailboxMemoryHandle) throws {
        let response = try propertyRequest(forTag: .unlockMemory, values: [ handle ])
        guard response.count == 1 else { throw RaspberryPiError.invalidMailboxResponse }
        guard response[0] == 0 else { throw RaspberryPiError.mailboxRequestFailed }
    }
    
    /// Release memory.
    ///
    /// - Parameters:
    ///   - handle: `MailboxMemoryHandle` to be released.
    ///
    /// - Throws: `RaspberryPiError` on failure.
    public func releaseMemory(handle: MailboxMemoryHandle) throws {
        let response = try propertyRequest(forTag: .releaseMemory, values: [ handle ])
        guard response.count == 1 else { throw RaspberryPiError.invalidMailboxResponse }
        guard response[0] == 0 else { throw RaspberryPiError.mailboxRequestFailed }
    }
    
}


/// Property request tags that are currently implemented.
enum MailboxPropertyTag: UInt32 {
    case allocateMemory = 0x3000c
    case lockMemory     = 0x3000d
    case unlockMemory   = 0x3000e
    case releaseMemory  = 0x3000f
}


/// Flags for `Mailbox.allocateMemory(size:alignment:flags)`
public struct MailboxAllocateMemoryFlags: OptionSet {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    /// Can be resized to 0 at any time. Use for cached data.
    public static let discardable   = MailboxAllocateMemoryFlags(rawValue: 1 << 0)
    
    /// Normal allocating alias. Don't use from ARM.
    public static let normal        = MailboxAllocateMemoryFlags(rawValue: 0 << 2)
    
    /// 0xC alias.  Uncached.
    public static let direct        = MailboxAllocateMemoryFlags(rawValue: 1 << 2)
    
    /// 0x8 alias.  Non-allocating in L2 but coherent.
    public static let coherent      = MailboxAllocateMemoryFlags(rawValue: 2 << 2)
    
    /// Initialize buffer to all zeros.
    public static let zero          = MailboxAllocateMemoryFlags(rawValue: 1 << 4)
    
    /// Don't initialize (default is to initialize to all ones.)
    public static let noInit        = MailboxAllocateMemoryFlags(rawValue: 1 << 5)
    
    /// Likely to be locked for long periods of time.
    public static let hintPermalock = MailboxAllocateMemoryFlags(rawValue: 1 << 6)
    
    /// Allocating in L2.
    public static let l1Nonallocating: MailboxAllocateMemoryFlags = [ .direct, .coherent ]
}

