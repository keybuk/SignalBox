//
//  Function.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

public struct Function0to4 : OptionSet, Packable {
    public let rawValue: Int

    public static let f1 = Function0to4(rawValue: 1 << 0)
    public static let f2 = Function0to4(rawValue: 1 << 1)
    public static let f3 = Function0to4(rawValue: 1 << 2)
    public static let f4 = Function0to4(rawValue: 1 << 3)
    public static let fl = Function0to4(rawValue: 1 << 4)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Function Group One.
        packer.add(0b100, length: 3)
        packer.add(rawValue, length: 5)
    }
}

public struct Function5to8 : OptionSet, Packable {
    public let rawValue: Int

    public static let f5 = Function5to8(rawValue: 1 << 0)
    public static let f6 = Function5to8(rawValue: 1 << 1)
    public static let f7 = Function5to8(rawValue: 1 << 2)
    public static let f8 = Function5to8(rawValue: 1 << 3)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Function Group Two.
        packer.add(0b101, length: 3)
        // Select F5-F8.
        packer.add(0b1, length: 1)
        packer.add(rawValue, length: 4)
    }
}

public struct Function9to12 : OptionSet, Packable {
    public let rawValue: Int

    public static let f9 = Function9to12(rawValue: 1 << 0)
    public static let f10 = Function9to12(rawValue: 1 << 1)
    public static let f11 = Function9to12(rawValue: 1 << 2)
    public static let f12 = Function9to12(rawValue: 1 << 3)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Function Group Two.
        packer.add(0b101, length: 3)
        // Select F9-F12.
        packer.add(0b0, length: 1)
        packer.add(rawValue, length: 4)
    }
}

public struct Function13to20 : OptionSet, Packable {
    public let rawValue: Int

    public static let f13 = Function13to20(rawValue: 1 << 0)
    public static let f14 = Function13to20(rawValue: 1 << 1)
    public static let f15 = Function13to20(rawValue: 1 << 2)
    public static let f16 = Function13to20(rawValue: 1 << 3)
    public static let f17 = Function13to20(rawValue: 1 << 4)
    public static let f18 = Function13to20(rawValue: 1 << 5)
    public static let f19 = Function13to20(rawValue: 1 << 6)
    public static let f20 = Function13to20(rawValue: 1 << 7)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Feature Expansion.
        packer.add(0b110, length: 3)
        // F13-F20 Function Control.
        packer.add(0b11110, length: 5)
        packer.add(rawValue, length: 8)
    }
}

public struct Function21to28 : OptionSet, Packable {
    public let rawValue: Int

    public static let f21 = Function21to28(rawValue: 1 << 0)
    public static let f22 = Function21to28(rawValue: 1 << 1)
    public static let f23 = Function21to28(rawValue: 1 << 2)
    public static let f24 = Function21to28(rawValue: 1 << 3)
    public static let f25 = Function21to28(rawValue: 1 << 4)
    public static let f26 = Function21to28(rawValue: 1 << 5)
    public static let f27 = Function21to28(rawValue: 1 << 6)
    public static let f28 = Function21to28(rawValue: 1 << 7)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Feature Expansion.
        packer.add(0b110, length: 3)
        // F21-F28 Function Control.
        packer.add(0b11111, length: 5)
        packer.add(rawValue, length: 8)
    }
}
