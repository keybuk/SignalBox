//
//  RaspberryPi.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/1/18.
//

import Foundation

/// Raspberry Pi hardware.
///
/// Provides details about the Raspberry Pi hardware, such as memory addresses of peripherals.
public enum RaspberryPi {
    
    /// Location of the device tree ranges map.
    private static let deviceTreeRangesPath = "/proc/device-tree/soc/ranges"

    /// Bus address of I/O Peripherals.
    ///
    /// The bus address is the address utilized for hardware, including the DMA engine.
    public static let peripheralBusAddress: UInt32 = 0x7e000000

    /// Bus address of the uncached memory 'C' alias.
    ///
    /// The Raspberry Pi hardware provides an alias to memory addresses that bypasses the L1 and L2 caches, and can be allocated using `allocateUncachedMemory(minimumSize:)`. To translate the `busAddress` of that object into a un-aliased physical address, remove this constant from it; likewise to translate an un-aliased physical address into an aliased bus address, add this constant.
    public static let uncachedAliasBusAddress: UInt32 = 0xc0000000

    /// Physical address of I/O Peripherals on the earlier Pi models.
    internal static let bcm2835Address: UInt32 = 0x20000000

    /// Size of the I/O Peripherals address range on the earlier Pi models.
    internal static let bcm2835Size: Int = 0x01000000
    
    /// Physical address of I/O Peripherals.
    ///
    /// The physical address is the address visible to software running on the CPU, and from where
    /// we can map the I/O Peripheral registers into our own address space.
    public static var periperhalAddress: UInt32 = {
        // Only an older Raspberry Pi (or a platform we're running unit tests on) won't have the
        // necessary ranges in its device tree, so return the old address for any error reading
        // from the file.
        guard let rangesData = try? Data(contentsOf: URL(fileURLWithPath: deviceTreeRangesPath)) else {
            return RaspberryPi.bcm2835Address
        }

        // Read the raw ranges data as an array of big endian 32-bit integers.
        var addresses: [UInt32] = Array(repeating: 0, count: rangesData.count / MemoryLayout<UInt32>.stride)
        _ = addresses.withUnsafeMutableBytes { rangesData.copyBytes(to: $0) }
        addresses = addresses.map { $0.bigEndian }

        // Array contains triplets of bus address, physical address, range size.
        for index in stride(from: addresses.startIndex, to: addresses.endIndex, by: 3) {
            if addresses[index] == RaspberryPi.peripheralBusAddress {
                return addresses[addresses.index(after: index)]
            }
        }
        
        // Return the old address if there was no mapped range.
        return RaspberryPi.bcm2835Address
    }()

}
