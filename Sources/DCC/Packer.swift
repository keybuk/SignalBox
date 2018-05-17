//
//  Packer.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

import Foundation

/// A type that can pack its values using a Packer.
public protocol Packable {

    /// Adds the values from this type into the given packer.
    ///
    /// - parameters:
    ///   - packer: The packer to add to.
    func add<T : Packer>(into packer: inout T)
    
}

/// A type that can pack multiple values together into a structure.
///
/// A `Packer` can accept any type which conforms to `Packable`, which is itself defined as a
/// type that can itself into a `Packer`.
///
/// In addition a `Packer` can natively accept any fixed with integer value, with a specified
/// length in bits. This is the method that implementations of `Packer` need to provide to conform.
public protocol Packer {
    
    /// Add a field with the contents of a value.
    ///
    /// The length of the field is given in `length`. Only the least significant `length` bits from
    /// `value` are used for the contents of the field.
    ///
    /// - parameters:
    ///   - value: value to add.
    ///   - length: length of the field.
    mutating func add<T>(_ value: T, length: Int) where T : FixedWidthInteger
    
    /// Add a field with the given value.
    ///
    /// - parameters:
    ///   - value: value to add.
    mutating func add(_ value: Packable)
    
}

extension Packer {

    // Provide a default implementation that uses `Packable`.
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


