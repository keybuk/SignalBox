//
//  UncachedMemory.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Region of Uncached Memory.
///
/// Uncached memory is accessed through the Raspberry Pi's "'C' Alias" such that all reads directly
/// come from, and all writes directly go to, RAM bypassing the core's L1 and L2 caches. While such
/// accesses are significantly slower, this allows for interacting with hardware such as the DMA
/// Engine which cannot _see_ these caches.
///
/// Instances of this object must be retained as long as the region is required. The instance will
/// release the memory region on deinitialization. In addition, due to the way in which uncached
/// memory is allocated, the memory region is **not** automatically released on process exit.
/// You must deallocate it manually by either releasing the object or calling `deallocate()`.
///
/// The region is accessed through the `pointer` member; accessing this after deallocation will
/// trap.
public final class UncachedMemory {

    /// Mailbox handle for the memory region, used to release it.
    private var handle: Mailbox.MemoryHandle?

    /// Pointer to the region.
    public let pointer: UnsafeMutableRawPointer

    /// Bus address of the region.
    ///
    /// This address is within the "'C' Alias" and may be handed directly to hardware such as the
    /// DMA Engine.
    public let busAddress: UInt32

    /// Size of the region
    public let size: Int

    /// - Parameters:
    ///   - minimumSize: minimum size of region to allocate, will be rounded up to complete pages.
    ///
    /// - Throws: `Mailbox.Error` or `OSError` on failure.
    public init(minimumSize: Int) throws {
        size = Int(PAGE_SIZE) * ((minimumSize - 1) / Int(PAGE_SIZE) + 1)

        let memoryDevice = try MemoryDevice()
        let mailbox = try Mailbox()

        // From this point on, we have to remember to release the allocated memory on failure.
        let handle = try mailbox.allocateMemory(size: size, alignment: Int(PAGE_SIZE), flags: .direct)
        do {
            busAddress = try mailbox.lockMemory(handle: handle)
            let address = busAddress & ~RaspberryPi.uncachedAliasBusAddress

            pointer = try memoryDevice.map(address: address, size: size)
            self.handle = handle
        } catch {
            try! mailbox.releaseMemory(handle: handle)
            throw error
        }
    }

    /// Release the region.
    ///
    /// This is automatically called on object destruction, but may be called in advance if
    /// necessary. Uncached memory regions must be deallocated manually on process exit, otherwise
    /// the region will remain allocated.
    ///
    /// Accessing the memory region through `pointer` after calling this method will result in a
    /// runtime error.
    ///
    /// - Throws: `Mailbox.Error` or `OSError` on failure.
    public func deallocate() throws {
        guard let handle = handle else { return }

        // Release the memory with the mailbox first; since it matters more whether this takes place
        /// than the munmap.
        let mailbox = try Mailbox()
        try mailbox.releaseMemory(handle: handle)
        self.handle = nil

        try MemoryDevice.unmap(pointer, size: size)
    }

    deinit {
        // There isn't much we can do if we fail to release memory. Fortunately it's one of those
        /// operations that also shouldn't ever happen.
        do {
            try deallocate()
        } catch {
            print("Unexpected error during memory release: \(error)")
            print("!!! MEMORY MAY STILL BE ALLOCATED !!!")
        }
    }

}

