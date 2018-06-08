//
//  MappedRegisters.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/8/18.
//

/// Type mapping hardware registers.
///
/// Hardware access on the RaspberryPi is handled through registers at specific memory addresses.
/// Classes handling such hardware may conform to this protocol.
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
    static var offset: UInt32 { get }

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
        return RaspberryPi.peripheralBusAddress + offset
    }

    /// Physical address of the registers
    public static var address: UInt32 {
        return RaspberryPi.periperhalAddress + offset
    }

}
