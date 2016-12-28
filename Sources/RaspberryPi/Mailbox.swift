//
//  Mailbox.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/21/16.
//
//

import Foundation

/// Errors that can be thrown by `Mailbox`.
public enum MailboxError: Error {
    
    /// The request was invalid.
    case invalidRequest
    
    /// The response received was invalid.
    case invalidResponse
    
    /// The request failed.
    case requestFailed

}

/// Raspberry Pi Mailbox Property interface.
///
/// This class implements the Mailbox Property interface used to communicate to the VideoCore of the Raspberry Pi.
///
/// Only the memory allocation and locking properties are implemented at this time.
///
/// Documentation is available at https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
public class Mailbox {
    
    // _IOWR(100, 0, char *)
    let mailboxPropertyIoctl: UInt = ((1 | 2) << 30) | (100 << 8) | (0 << 0) | (4 << 16)

    let mailboxPath = "/dev/vcio"
    let fileHandle: FileHandle
    
    public init() throws {
        fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: mailboxPath))
    }
    
    /// Property request tags that are currently implemented.
    enum Tag: UInt32 {
        case allocateMemory = 0x3000c
        case lockMemory     = 0x3000d
        case unlockMemory   = 0x3000e
        case releaseMemory  = 0x3000f
        case end            = 0x00000
    }
    
    /// Values for property request's code member.
    let processRequestCode: UInt32    = 0x00000000
    let requestSuccessfulCode: UInt32 = 0x80000000
    let parseErrorCode: UInt32        = 0x80000001
    
    /// Bit used to indicate values member was filled by response.
    let responseValuesIndicator: UInt32 = 1 << 31

    /// Make a property request.
    ///
    /// - Parameters:
    ///   - tag: mailbox property tag to request.
    ///   - values: request values for the tag.
    ///
    /// - Returns: array of response values.
    ///
    /// - Throws:
    ///   `MailboxError.invalidRequest` when the mailbox call fails, or if the mailbox returns a parse error status.
    ///   `MailboxError.invalidResponse` if the response does not match the expected format.
    ///   `MailboxError.requestFailed` for any other failure.
    func propertyRequest(forTag tag: Tag, values: [UInt32]) throws -> [UInt32] {
        let bufferSize = 6 + values.count
        var buffer: [UInt32] = Array(repeating: 0, count: bufferSize)
        
        buffer[0] = UInt32(MemoryLayout<UInt32>.stride * bufferSize)
        buffer[1] = processRequestCode
        buffer[2] = tag.rawValue
        buffer[3] = UInt32(MemoryLayout<UInt32>.stride * values.count)
        buffer[4] = UInt32(MemoryLayout<UInt32>.stride * values.count)

        buffer.replaceSubrange(5..<(5 + values.count), with: values)
        buffer[5 + values.count] = Tag.end.rawValue
        
        let result = ioctl(fileHandle.fileDescriptor, mailboxPropertyIoctl, UnsafeMutableRawPointer(mutating: buffer))
        if result < 0 {
            if errno == EINVAL {
                throw MailboxError.invalidRequest
            } else {
                throw MailboxError.requestFailed
            }
        }

        switch buffer[1] {
        case requestSuccessfulCode:
            guard buffer[4] & responseValuesIndicator != 0 else {
                throw MailboxError.invalidResponse
            }
            
            let numberOfValues = Int(buffer[4] & ~responseValuesIndicator) / MemoryLayout<UInt32>.stride
            return Array(buffer[5..<(5 + numberOfValues)])
        case parseErrorCode:
            throw MailboxError.invalidRequest
        default:
            throw MailboxError.invalidResponse
        }
    }
    
    /// Handle to memory on the GPU.
    public typealias MemoryHandle = UInt32
    
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
    /// - Returns: `MemoryHandle` for allocated memory.
    ///
    /// - Throws:
    ///   `MailboxError.invalidRequest` when the mailbox call fails, or if the mailbox returns a parse error status.
    ///   `MailboxError.invalidResponse` if the response does not match the expected format.
    public func allocateMemory(size: Int, alignment: Int, flags: MailboxAllocateMemoryFlags) throws -> MemoryHandle {
        let response = try propertyRequest(forTag: .allocateMemory, values: [ UInt32(size), UInt32(alignment), flags.rawValue ])
        guard response.count == 1 else { throw MailboxError.invalidResponse }
        
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
    /// - Throws:
    ///   `MailboxError.invalidRequest` when the mailbox call fails, or if the mailbox returns a parse error status.
    ///   `MailboxError.invalidResponse` if the response does not match the expected format.
    public func lockMemory(handle: MemoryHandle) throws -> Int {
        let response = try propertyRequest(forTag: .lockMemory, values: [ handle ])
        guard response.count == 1 else { throw MailboxError.invalidResponse }

        return Int(bitPattern: UInt(response[0]))
    }
    
    /// Unlock memory.
    ///
    /// The memory will retain its contents, but may move.
    ///
    /// - Parameters:
    ///   - handle: `MemoryHandle` to be unlocked.
    ///
    /// - Throws:
    ///   `MailboxError.invalidRequest` when the mailbox call fails, or if the mailbox returns a parse error status.
    ///   `MailboxError.invalidResponse` if the response does not match the expected format.
    ///   `MailboxError.requestFailed` if the memory could not be unlocked.
    public func unlockMemory(handle: MemoryHandle) throws {
        let response = try propertyRequest(forTag: .unlockMemory, values: [ handle ])
        guard response.count == 1 else { throw MailboxError.invalidResponse }
        guard response[0] == 0 else { throw MailboxError.requestFailed }
    }
    
    /// Release memory.
    ///
    /// - Parameters:
    ///   - handle: `MemoryHandle` to be released.
    ///
    /// - Throws:
    ///   `MailboxError.invalidRequest` when the mailbox call fails, or if the mailbox returns a parse error status.
    ///   `MailboxError.invalidResponse` if the response does not match the expected format.
    ///   `MailboxError.requestFailed` if the memory could not be released.
    public func releaseMemory(handle: MemoryHandle) throws {
        let response = try propertyRequest(forTag: .releaseMemory, values: [ handle ])
        guard response.count == 1 else { throw MailboxError.invalidResponse }
        guard response[0] == 0 else { throw MailboxError.requestFailed }
    }
    
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

