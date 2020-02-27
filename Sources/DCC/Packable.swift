//
//  Packable.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

/// A type that can pack its values using a Packer.
///
/// Types can conform by packing their members through their own `Packable` conformance, or by using
/// the `add(length:)` method of `Packer`.
public protocol Packable {
    /// Adds the values from this type into the given packer.
    ///
    /// - parameters:
    ///   - packer: The packer to add to.
    func add<T : Packer>(into packer: inout T)
}

// Extend `Packer` to add any type that conforms to `Packable`.
extension Packer {
    /// Add a field with the given value.
    ///
    /// - parameters:
    ///   - value: value to add.
    public mutating func add(_ value: Packable) {
        value.add(into: &self)
    }
}

extension Bool : Packable {
    // Provide conformance to `Packable` for `Bool` by adding a single bit.
    public func add<T : Packer>(into packer: inout T) {
        packer.add(self ? 1 : 0, length: 1)
    }
}

extension FixedWidthInteger where Self : Packable {
    // Provide conformance to `Packable` for all fixed width integers by using
    // their bitWidth.
    public func add<T : Packer>(into packer: inout T) {
        packer.add(self, length: bitWidth)
    }
}

// Extend the fixed-width integers, but exclude Int and UInt since their width
// varies by platform and that kind of thing introduces bugs!
extension Int8 : Packable {}
extension Int16 : Packable {}
extension Int32 : Packable {}
extension Int64 : Packable {}
extension UInt8 : Packable {}
extension UInt16 : Packable {}
extension UInt32 : Packable {}
extension UInt64 : Packable {}

// FIXME: get rid of this since we end up stuck choosing between heterogenous
// and homogenous arrays.
extension Array : Packable where Element == Packable {
    // Provide conformance to `Packable` for Arrays of `Packable` by iterating
    // their elements.
    public func add<T : Packer>(into packer: inout T) {
        for element in self {
            element.add(into: &packer)
        }
    }
}
