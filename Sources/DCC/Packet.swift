//
//  Packet.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

import Foundation

public protocol Packet : Packable {
    
    var bytes: [UInt8] { get }

}

public extension Packet {
    
    public func add<T : Packer>(into packer: inout T) {
        let bytes = self.bytes
        for byte in bytes {
            packer.add(0, length: 1)
            packer.add(byte, length: 8)
        }
        
        let errorDetectionByte = bytes.reduce(0, { $0 ^ $1 })
        packer.add(0, length: 1)
        packer.add(errorDetectionByte, length: 8)
        
        packer.add(1, length: 1)
    }
    
}

public struct MultiFunctionPacket : Packet {
    
    public var address: Int
    public var instructions: [MultiFunctionInstruction]
    
    public var bytes: [UInt8] {
        var packer = BytePacker()

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

public protocol MultiFunctionInstruction : Packable {}

public protocol DecoderAndConsistControlInstruction : MultiFunctionInstruction {}

public struct DecoderResetInstruction : DecoderAndConsistControlInstruction {
    
    var isHardReset: Bool = false
    
    public func add<T : Packer>(into packer: inout T) {
        packer.add(0b0000, length: 4)
        packer.add(0b000, length: 3)
        packer.add(isHardReset)
    }
    
}

public struct DecoderAcknowledgementRequest : DecoderAndConsistControlInstruction {
    
    public func add<T : Packer>(into packer: inout T) {
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
    
    public func add<T : Packer>(into packer: inout T) {
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
                packer.add(0b0000, length: 4)
            default:
                let adjustedSpeed = speed + 3
                packer.add(adjustedSpeed & 1, length: 1)
                packer.add(adjustedSpeed >> 1, length: 4)
            }
        }
    }
    
}


public struct Preamble : Packable {
    
    public var timing: BitstreamTiming
    public var withCutout: Bool
    
    init(timing: BitstreamTiming, withCutout: Bool = true) {
        self.timing = timing
        self.withCutout = withCutout
    }
    
    public func add<T : Packer>(into packer: inout T) {
        let count = withCutout ? timing.preambleCount : BitstreamTiming.preambleCountMin
        if count <= UInt64.bitWidth {
            let bits: UInt64 = ~(~0 << count)
            packer.add(bits, length: count)
        } else {
            for _ in 0..<count {
                packer.add(1, length: 1)
            }
        }
    }
    
}

