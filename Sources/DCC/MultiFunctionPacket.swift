//
//  MultiFunctionPacket.swift
//  DCC
//
//  Created by Scott James Remnant on 5/15/18.
//

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
    
    public var isHardReset: Bool = false
    
    public func add<T : Packer>(into packer: inout T) {
        // Decoder Control.
        packer.add(0b0000, length: 4)
        // Digital Decoder Reset.
        packer.add(0b000, length: 3)
        packer.add(isHardReset)
    }
    
}

public struct SetDecoderFlagsInstruction : DecoderAndConsistControlInstruction {
    
    public enum Flag {
        case disable111
        case disableAcknowledgementRequeswt
        case activateBiDirectionalComms
        case setBiDirectionalComms
        case set111
        case accept111
    }
    
    public var flag: Flag
    public var isSet: Bool
    public var subAddress: Int
    
    public init(flag: Flag, isSet: Bool, subAddress: Int) {
        assert(subAddress >= 0 && subAddress >= 7, "Sub-address must be in range 0..7")
        
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
        case .disableAcknowledgementRequeswt:
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

public struct SetAdvancedAddressingInstruction : DecoderAndConsistControlInstruction {

    public var isSet: Bool
    
    public init(_ isSet: Bool) {
        self.isSet = isSet
    }
    
    public func add<T : Packer>(into packer: inout T) {
        // Decoder Control.
        packer.add(0b0000, length: 4)
        // Set Decoder Flags.
        packer.add(0b101, length: 3)
        packer.add(isSet)
    }


}

public struct DecoderAcknowledgementRequest : DecoderAndConsistControlInstruction {
    
    public func add<T : Packer>(into packer: inout T) {
        // Decoder Control.
        packer.add(0b0000, length: 4)
        // Decoder Acknowledgement Request.
        packer.add(0b111, length: 3)
        packer.add(0b1, length: 1)
    }
    
}

public enum Direction {
    case forward
    case reverse
}

public struct ConsistControlInstruction : DecoderAndConsistControlInstruction {
    
    public var consistAddress: Int
    public var direction: Direction

    public init(consistAddress: Int, direction: Direction = .forward) {
        assert(consistAddress >= 0 && consistAddress <= 127, "Consist address must be in range 0..127")
        
        self.consistAddress = consistAddress
        self.direction = direction
    }
    
    public func add<T : Packer>(into packer: inout T) {
        // Consist Control.
        packer.add(0b0001, length: 4)
        // Decoder Acknowledgement Request.
        packer.add(0b111, length: 3)
        packer.add(0b1, length: 1)
        
        switch direction {
        case .forward:
            packer.add(0b0010, length: 4)
        case .reverse:
            packer.add(0b0011, length: 4)
        }
        
        packer.add(0b0, length: 1)
        packer.add(consistAddress, length: 7)
    }

}

public protocol SpeedAndDirectionInstruction : MultiFunctionInstruction {}

public struct SpeedAndDirection14StepInstruction : SpeedAndDirectionInstruction {
    
    public var speed: Int
    public var direction: Direction
    public var headlight: Bool
    
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
        
        packer.add(headlight)
        
        switch speed {
        case 0:
            packer.add(0b0000, length: 4)
        default:
            let adjustedSpeed = speed + 1
            packer.add(adjustedSpeed, length: 4)
        }
    }
    
}

public struct EmergencyStop14StepInstruction : SpeedAndDirectionInstruction {
    
    public var direction: Direction
    public var headlight: Bool
    
    public init(direction: Direction, headlight: Bool) {
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
        
        packer.add(headlight)
        packer.add(0b00001, length: 5)
    }
    
}

public struct SpeedAndDirection28StepInstruction : SpeedAndDirectionInstruction {
    
    public var speed: Int
    public var direction: Direction
    public var ignoreDirection: Bool

    public init(speed: Int, direction: Direction, stopIgnoringDirection ignoreDirection: Bool = false) {
        assert(speed >= 0 && speed <= 28, "Speed must be within range 0...28")

        self.speed = speed
        self.direction = direction
        self.ignoreDirection = ignoreDirection
    }
    
    public func add<T : Packer>(into packer: inout T) {
        switch direction {
        case .forward:
            packer.add(0b011, length: 3)
        case .reverse:
            packer.add(0b010, length: 3)
        }
        
        switch speed {
        case 0:
            packer.add(ignoreDirection)
            packer.add(0b0000, length: 4)
        default:
            let adjustedSpeed = speed + 3
            packer.add(adjustedSpeed, length: 1)
            packer.add(adjustedSpeed >> 1, length: 4)
        }
    }

}

public struct EmergencyStop28StepInstruction : SpeedAndDirectionInstruction {
    
    public var direction: Direction
    public var ignoreDirection: Bool
    
    public init(direction: Direction, ignore ignoreDirection: Bool = true) {
        self.direction = direction
        self.ignoreDirection = ignoreDirection
    }
    
    public func add<T : Packer>(into packer: inout T) {
        switch direction {
        case .forward:
            packer.add(0b011, length: 3)
        case .reverse:
            packer.add(0b010, length: 3)
        }

        packer.add(ignoreDirection)
        packer.add(0b0001, length: 4)
    }
    
}

public protocol AdvancedOperationsInstruction : MultiFunctionInstruction {}

public struct SpeedAndDirection128StepInstruction : AdvancedOperationsInstruction {
    
    public var speed: Int
    public var direction: Direction
    
    public init(speed: Int, direction: Direction) {
        assert(speed >= 0 && speed <= 126, "Speed must be within range 0...126")
        
        self.speed = speed
        self.direction = direction
    }
    
    public func add<T : Packer>(into packer: inout T) {
        // Advanced Operations.
        packer.add(0b001, length: 3)
        // 128 Speed Step Control.
        packer.add(0b11111, length: 5)
        
        switch direction {
        case .forward:
            packer.add(0b1, length: 1)
        case .reverse:
            packer.add(0b0, length: 0)
        }
        
        switch speed {
        case 0:
            packer.add(0b0000000, length: 7)
        default:
            let adjustedSpeed = speed + 1
            packer.add(adjustedSpeed, length: 7)
        }
    }
    
}

public struct EmergencyStop128StepInstruction : AdvancedOperationsInstruction {
    
    public var direction: Direction
    
    public init(direction: Direction) {
        self.direction = direction
    }
    
    public func add<T : Packer>(into packer: inout T) {
        // Advanced Operations.
        packer.add(0b001, length: 3)
        // 128 Speed Step Control.
        packer.add(0b11111, length: 5)
        
        switch direction {
        case .forward:
            packer.add(0b1, length: 1)
        case .reverse:
            packer.add(0b0, length: 0)
        }
        
        packer.add(0b0000001, length: 7)
    }
    
}

public struct RestrictedSpeedStepInstruction : AdvancedOperationsInstruction {
    
    public var isRestricted: Bool
    public var speed: Int
    public var direction: Direction
    
    public init(isRestricted: Bool, speed: Int, direction: Direction) {
        assert(speed >= 0 && speed <= 28, "Speed must be within range 0...28")
        
        self.isRestricted = isRestricted
        self.speed = speed
        self.direction = direction
    }
    
    public func add<T : Packer>(into packer: inout T) {
        // Advanced Operations.
        packer.add(0b001, length: 3)
        // Restricted Speed Step Control.
        packer.add(0b11110, length: 5)
        
        // It's not clear whether direction is meaningful, but include it since there is a bit
        // reserved for it.
        switch direction {
        case .forward:
            packer.add(0b1, length: 1)
        case .reverse:
            packer.add(0b0, length: 0)
        }
        
        switch speed {
        // Emergency Stop is not handled, and not clear whether it's meaningful.
        case 0:
            // Ignore-direction stop is not handled, and not clear whether it's meaningful.
            packer.add(0b00000, length: 5)
        default:
            // FIXME: I don't like that this is copied.
            let adjustedSpeed = speed + 3
            packer.add(adjustedSpeed, length: 1)
            packer.add(adjustedSpeed >> 1, length: 4)
        }
    }
    
}

public enum AnalogOutput : Int {
    
    case volumeControl = 0b00000001

}

public struct AnalogFunctionInstruction : AdvancedOperationsInstruction {
    
    public var output: Int
    public var data: UInt8
    
    public init(output: AnalogOutput, data: UInt8) {
        self.output = output.rawValue
        self.data = data
    }
    
    public init(output: Int, data: UInt8) {
        assert(output >= 0 && output <= 255, "Output must be within range 0...255")

        self.output = output
        self.data = data
    }
 
    public func add<T : Packer>(into packer: inout T) {
        // Advanced Operations.
        packer.add(0b001, length: 3)
        // Analog Function Group.
        packer.add(0b11101, length: 5)
        packer.add(output, length: 8)
        packer.add(data)
    }
    
}

public struct Function0to4Instruction : MultiFunctionInstruction, OptionSet {
    
    public let rawValue: Int
    
    public static let f1 = Function0to4Instruction(rawValue: 1 << 0)
    public static let f2 = Function0to4Instruction(rawValue: 1 << 1)
    public static let f3 = Function0to4Instruction(rawValue: 1 << 2)
    public static let f4 = Function0to4Instruction(rawValue: 1 << 3)
    public static let fl = Function0to4Instruction(rawValue: 1 << 4)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Function Group One.
        packer.add(0b100, length: 3)
        packer.add(rawValue, length: 5)
    }

}

public struct Function5to8Instruction : MultiFunctionInstruction, OptionSet {
    
    public let rawValue: Int
    
    public static let f5 = Function5to8Instruction(rawValue: 1 << 0)
    public static let f6 = Function5to8Instruction(rawValue: 1 << 1)
    public static let f7 = Function5to8Instruction(rawValue: 1 << 2)
    public static let f8 = Function5to8Instruction(rawValue: 1 << 3)
    
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

public struct Function9to12Instruction : MultiFunctionInstruction, OptionSet {
    
    public let rawValue: Int
    
    public static let f9 = Function9to12Instruction(rawValue: 1 << 0)
    public static let f10 = Function9to12Instruction(rawValue: 1 << 1)
    public static let f11 = Function9to12Instruction(rawValue: 1 << 2)
    public static let f12 = Function9to12Instruction(rawValue: 1 << 3)
    
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

public protocol FeatureExpansionInstruction : MultiFunctionInstruction {}

public struct Function13to20Instruction : FeatureExpansionInstruction, OptionSet {
    
    public let rawValue: Int
    
    public static let f13 = Function13to20Instruction(rawValue: 1 << 0)
    public static let f14 = Function13to20Instruction(rawValue: 1 << 1)
    public static let f15 = Function13to20Instruction(rawValue: 1 << 2)
    public static let f16 = Function13to20Instruction(rawValue: 1 << 3)
    public static let f17 = Function13to20Instruction(rawValue: 1 << 4)
    public static let f18 = Function13to20Instruction(rawValue: 1 << 5)
    public static let f19 = Function13to20Instruction(rawValue: 1 << 6)
    public static let f20 = Function13to20Instruction(rawValue: 1 << 7)

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

public struct Function21to28Instruction : FeatureExpansionInstruction, OptionSet {
    
    public let rawValue: Int
    
    public static let f21 = Function21to28Instruction(rawValue: 1 << 0)
    public static let f22 = Function21to28Instruction(rawValue: 1 << 1)
    public static let f23 = Function21to28Instruction(rawValue: 1 << 2)
    public static let f24 = Function21to28Instruction(rawValue: 1 << 3)
    public static let f25 = Function21to28Instruction(rawValue: 1 << 4)
    public static let f26 = Function21to28Instruction(rawValue: 1 << 5)
    public static let f27 = Function21to28Instruction(rawValue: 1 << 6)
    public static let f28 = Function21to28Instruction(rawValue: 1 << 7)
    
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

public struct BinaryStateControlInstruction : FeatureExpansionInstruction {
    
    public var stateAddress: Int
    public var isEnabled: Bool
    
    public init(setAllTo isEnabled: Bool) {
        self.stateAddress = 0
        self.isEnabled = isEnabled
    }
    
    public init(stateAddress: Int, isEnabled: Bool) {
        assert(stateAddress >= 1 && stateAddress <= 32767, "Binary State Address must be within range 1...32767")
        
        self.stateAddress = stateAddress
        self.isEnabled = isEnabled
    }
    
    public func add<T>(into packer: inout T) where T : Packer {
        // Feature Expansion.
        packer.add(0b110, length: 3)
        // Binary State Control.
        packer.add(0b00000, length: 5)
        packer.add(isEnabled)
        packer.add(stateAddress, length: 7)
        // Only send three-byte form when necessary: NMRA S-9.2.1 299-302.
        if stateAddress == 0 || stateAddress > 127 {
            packer.add(stateAddress >> 7, length: 8)
        }
    }
    
}

public protocol ConfigurationVariableInstruction : MultiFunctionInstruction {}

public struct ConfigurationVariableAccessShortInstruction : ConfigurationVariableInstruction {
    
    public var variable: ConfigurationVariable
    public var data: UInt8
    
    public init(variable: ConfigurationVariable, data: UInt8) {
        assert(variable == .accelerationAdjustment || variable == .decelerationAdjustment, "Short form configuration variable acccess may only be used with Acceleration or Deceleration values.")
        
        self.variable = variable
        self.data = data
    }
    
    public func add<T>(into packer: inout T) where T : Packer {
        // Configuration Variable Access - Short Form.
        packer.add(0b1111, length: 4)
        
        switch variable {
        case .accelerationAdjustment:
            packer.add(0b0010, length: 4)
        case .decelerationAdjustment:
            packer.add(0b0011, length: 4)
        default:
            fatalError("Configuration variable not suitable for short form.")
        }
        
        packer.add(data)
    }
    
}

public struct ConfigurationVariableAccessInstruction : ConfigurationVariableInstruction {
    
    public enum Operation {
        case verify
        case write
    }

    public var operation: Operation
    public var variable: ConfigurationVariable
    public var data: UInt8

    public init(variable: ConfigurationVariable, verify data: UInt8) {
        self.operation = .verify
        self.variable = variable
        self.data = data
    }
    
    public init(variable: ConfigurationVariable, write data: UInt8) {
        self.operation = .write
        self.variable = variable
        self.data = data
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Configuration Variable Access - Long Form.
        packer.add(0b1110, length: 4)
        
        switch operation {
        case .verify:
            packer.add(0b01, length: 2)
        case .write:
            packer.add(0b11, length: 2)
        }
        
        let adjustedValue = variable.rawValue - 1
        packer.add(adjustedValue >> 8, length: 2)
        packer.add(adjustedValue, length: 8)
        
        packer.add(data)
    }

}

public struct ConfigurationVariableBitManipulation : ConfigurationVariableInstruction {
    
    public enum Operation {
        case verify
        case write
    }
    
    public var operation: Operation
    public var variable: ConfigurationVariable
    public var bit: Int
    public var isSet: Bool
    
    public init(variable: ConfigurationVariable, bit: Int, verify isSet: Bool) {
        assert(bit >= 0 && bit <= 7, "Bit must be in range 0...7")
        
        self.operation = .verify
        self.variable = variable
        self.bit = bit
        self.isSet = isSet
    }
    
    public init(variable: ConfigurationVariable, bit: Int, write isSet: Bool) {
        assert(bit >= 0 && bit <= 7, "Bit must be in range 0...7")
        
        self.operation = .write
        self.variable = variable
        self.bit = bit
        self.isSet = isSet
    }

    public func add<T>(into packer: inout T) where T : Packer {
        // Configuration Variable Access - Long Form.
        packer.add(0b1110, length: 4)
        // Bit Manipulation.
        packer.add(0b10, length: 2)

        let adjustedValue = variable.rawValue - 1
        packer.add(adjustedValue >> 8, length: 2)
        packer.add(adjustedValue, length: 8)

        packer.add(0b111, length: 3)

        switch operation {
        case .verify:
            packer.add(0b0, length: 1)
        case .write:
            packer.add(0b1, length: 1)
        }
        
        packer.add(isSet)

        packer.add(bit, length: 3)
    }
    
}
