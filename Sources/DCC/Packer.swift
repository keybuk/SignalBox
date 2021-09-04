//
//  Packer.swift
//  DCC
//
//  Created by Scott James Remnant on 11/3/19.
//

import Foundation

/// A type that can pack multiple values together into a structure.
///
/// To conform an implementation must provide a method that can accept any fixed with integer value, with a
/// specified length in bits, where that number of least significant bits of the value are packed into the
/// structure.
///
/// The resulting structure is available in `packedValues`.
public protocol Packer {
    /// The type of the structure containing the packed values.
    associatedtype PackedValues
    
    /// The structure of packed values.
    var packedValues: PackedValues { get }
    
    /// Add a field with the contents of a value.
    ///
    /// The length of the field is given in `length`. Only the least significant `length` bits from
    /// `value` are used for the contents of the field.
    ///
    /// - parameters:
    ///   - value: value to add.
    ///   - length: length of the field.
    mutating func add<T>(_ value: T, length: Int) where T : FixedWidthInteger
}
