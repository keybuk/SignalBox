//
//  DecoderControl.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

public struct DecoderReset : Packable {
    public var isHardReset: Bool = false

    public init(isHardReset: Bool = false) {
        self.isHardReset = isHardReset
    }

    public func add<T : Packer>(into packer: inout T) {
        // Decoder Control.
        packer.add(0b0000, length: 4)
        // Digital Decoder Reset.
        packer.add(0b000, length: 3)
        packer.add(isHardReset)
    }
}

public struct SetDecoderFlags : Packable {
    public enum Flag {
        case disable111
        case disableAcknowledgementRequest
        case activateBiDirectionalComms
        case setBiDirectionalComms
        case set111
        case accept111
    }

    public var flag: Flag
    public var isSet: Bool

    // NOTE: 0 means all
    @Clamping(0...7)
    public var subAddress: Int = 0

    public init(flag: Flag, isSet: Bool, subAddress: Int = 0) {
        self.flag = flag
        self.isSet = isSet
        self.subAddress = subAddress
    }

    public func add<T : Packer>(into packer: inout T) {
        // Decoder Control.
        packer.add(0b0000, length: 4)
        // Set Decoder Flags.
        packer.add(0b011, length: 3)
        packer.add(isSet)

        switch flag {
        case .disable111:
            packer.add(0b0000, length: 4)
        case .disableAcknowledgementRequest:
            packer.add(0b0100, length: 4)
        case .activateBiDirectionalComms:
            packer.add(0b0101, length: 4)
        case .setBiDirectionalComms:
            packer.add(0b1000, length: 4)
        case .set111:
            packer.add(0b1001, length: 4)
        case .accept111:
            packer.add(0b1111, length: 4)
        }

        packer.add(0b0, length: 1)
        packer.add(subAddress, length: 3)
    }
}

public struct SetAdvancedAddressing : Packable {
    public var isSet: Bool

    public init(_ isSet: Bool) {
        self.isSet = isSet
    }

    public func add<T : Packer>(into packer: inout T) {
        // Decoder Control.
        packer.add(0b0000, length: 4)
        // Set Advanced Addressing.
        packer.add(0b101, length: 3)
        packer.add(isSet)
    }
}

public struct DecoderAcknowledgementRequest : Packable {
    public init() {}

    public func add<T : Packer>(into packer: inout T) {
        // Decoder Control.
        packer.add(0b0000, length: 4)
        // Decoder Acknowledgement Request.
        packer.add(0b111, length: 3)
        packer.add(0b1, length: 1)
    }
}
