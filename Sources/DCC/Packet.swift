//
//  Packet.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

import Foundation

public protocol Packet {
    
    var bytes: [UInt8] { get }
    
    func errorDetectionByte(for bytes: [UInt8]) -> UInt8

}

public extension Packet {
    
    // FIXME: this still doesn't feel right.
    // - it's a method that takes `bytes` in as an argument, rather than a computed property
    // - but since bytes is a computed property, we can't just use that here either
    // - feels "generic" and not related to the value type
    // - but I want it to be with Packet, and not elsewhere.
    // - bytes ends up not having the error detection byte in it
    // - but that also means we can make new Packet anywhere, and don't have to remember to add it
    func errorDetectionByte(for bytes: [UInt8]) -> UInt8 {
        return bytes.reduce(0, { $0 ^ $1 })
    }
    
}

public struct MultiFunctionPacket : Packet {
    
    public var address: Int
    public var instructions: [MultiFunctionInstruction]
    
    public var bytes: [UInt8] {
        var packer = BitPacker()

        switch address {
        case 0:
            packer.add(0, length: 8)
        case 1...127:
            packer.add(address, length: 8)
        case 128...9999:
            packer.add(0b11, length: 2)
            packer.add(address, length: 14)
        default:
            fatalError("Address \(address) out of range for multi-function decoder")
        }
        
        // FIXME: verify that the set of instructions is legal.
        // - only one of decoder/consist control
        // - only one of advanced operations
        // - multiple speed/direction
        // - multiple function group one/two
        // - multiple feature expansion
        // - only one cv access
        // - optional decoder acknowledgement
        
        for instruction in instructions {
            instruction.add(into: &packer)
        }
        
        return packer.bytes
    }
    
}

public protocol MultiFunctionInstruction : BitPackable {}

public protocol DecoderAndConsistControlInstruction : MultiFunctionInstruction {}

public struct DecoderResetInstruction : DecoderAndConsistControlInstruction {
    
    var isHardReset: Bool = false
    
    public func add(into packer: inout BitPacker) {
        packer.add(0b0000, length: 4)
        packer.add(0b000, length: 3)
        packer.add(isHardReset)
    }
    
}

public struct DecoderAcknowledgementRequest : DecoderAndConsistControlInstruction {
    
    public func add(into packer: inout BitPacker) {
        packer.add(0b0000, length: 4)
        packer.add(0b111, length: 3)
        packer.add(0b1, length: 1)
    }
    
}

public enum Direction {
    case forward
    case reverse
}

public struct SpeedAndDirectionInstruction : MultiFunctionInstruction {
    
    var speed: Int
    var direction: Direction
    var headlight: Bool? = nil
    
    // FIXME: Maybe split into a 14-step and a 28-step variation
    public init(speed: Int, direction: Direction) {
        assert(speed >= 0 && speed <= 28, "Speed must be within range 0...28")
        
        self.speed = speed
        self.direction = direction
    }
    
    public init(speed: Int, direction: Direction, headlight: Bool) {
        assert(speed >= 0 && speed <= 14, "Speed must be within range 0...14")
        
        self.speed = speed
        self.direction = direction
        self.headlight = headlight
    }
    
    public func add(into packer: inout BitPacker) {
        switch direction {
        case .forward:
            packer.add(0b011, length: 3)
        case .reverse:
            packer.add(0b010, length: 3)
        }
        
        if let headlight = headlight {
            // 14-Step speed instruction with headlight.
            packer.add(headlight)
            
            switch speed {
            // FIXME: Emergency Stop is not handled.
            case 0:
                packer.add(0b0000, length: 4)
            default:
                let adjustedSpeed = speed + 1
                packer.add(adjustedSpeed, length: 4)
            }
        } else {
            // 28-Step speed instruction.
            switch speed {
            // FIXME: Emergency Stop is not handled.
            case 0:
                // FIXME: Ignore-direction stop is not handled.
                packer.add(0b0000, at: 3, length: 4)
            default:
                let adjustedSpeed = speed + 3
                packer.add(adjustedSpeed & 1, length: 1)
                packer.add(adjustedSpeed >> 1, length: 4)
            }
        }
    }
    
}
