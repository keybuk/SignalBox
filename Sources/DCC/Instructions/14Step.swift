//
//  14Step.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

/// 14-step Speed and Direction instruction
///
/// This is used when bit 1 of CV#29 has a value of zero, otherwise `Speed28Step` should be used.
///
/// - Note:
///   Sends a Speed and Direction Instruction as defined in NMRA S-9.2.1 C, compatible with the Baseline
///   Speed and Direction Packet defined in NMRA S-9.2 B.
public struct Speed14Step : Packable, CustomStringConvertible {
    /// Direction of travel.
    public var direction: Direction

    /// Speed of travel.
    ///
    /// Clamped to the range 0...14.
    @Clamping(0...14)
    public var speed: Int = 0

    /// Whether the headlight (FL) should be on or off.
    public var headlight: Bool

    public init(_ speed: Int, direction: Direction, headlight: Bool) {
        self.direction = direction
        self.headlight = headlight
        self.speed = speed
    }

    public func add<T>(into packer: inout T) where T : Packer {
        switch direction {
        case .reverse:
            packer.add(0b010, length: 3)
        case .forward:
            packer.add(0b011, length: 3)
        }

        packer.add(headlight)

        if speed > 0 {
            let adjustedSpeed = speed + 1
            packer.add(adjustedSpeed, length: 4)
        } else {
            packer.add(speed, length: 4)
        }
    }

    public var description: String {
        "<14-step speed \(direction) \(speed)\(headlight ? " FL" : "")>"
    }
}

/// 14-step Stop instruction
///
/// Equivalent to `Speed14Step(0)`, the decoder will come to stop based on its own configuration.
///
/// This is used when bit 1 of CV#29 has a value of zero, otherwise `Speed28Step` should be used.
///
/// - Note:
///   Sends a Speed and Direction Instruction as defined in NMRA S-9.2.1 C, compatible with the Baseline
///   Speed and Direction Packet defined in NMRA S-9.2 B.
public struct Stop14Step : Packable, CustomStringConvertible {
    /// Direction of travel while stopping.
    public var direction: Direction

    /// Whether the headlight (FL) should be on or off while stopping.
    public var headlight: Bool

    public init(direction: Direction, headlight: Bool) {
        self.direction = direction
        self.headlight = headlight
    }

    public func add<T>(into packer: inout T) where T : Packer {
        switch direction {
        case .reverse:
            packer.add(0b010, length: 3)
        case .forward:
            packer.add(0b011, length: 3)
        }

        packer.add(headlight)
        packer.add(0b0000, length: 4)
    }

    public var description: String {
        "<14-step stop \(direction)\(headlight ? " FL" : "")>"
    }
}

/// 14-step Emergency Stop instruction
///
/// The decoder immediately stops delivering power to the motor.
///
/// This is used when bit 1 of CV#29 has a value of zero, otherwise `Speed28Step` should be used.
///
/// - Note:
///   Sends a Speed and Direction Instruction as defined in NMRA S-9.2.1 C, compatible with the Baseline
///   Speed and Direction Packet defined in NMRA S-9.2 B.
public struct EmergencyStop14Step : Packable, CustomStringConvertible {
    /// Direction of travel while stopping.
    public var direction: Direction

    /// Whether the headlight (FL) should be on or off while stopping.
    public var headlight: Bool

    public init(direction: Direction, headlight: Bool) {
        self.direction = direction
        self.headlight = headlight
    }

    public func add<T>(into packer: inout T) where T : Packer {
        switch direction {
        case .reverse:
            packer.add(0b010, length: 3)
        case .forward:
            packer.add(0b011, length: 3)
        }

        packer.add(headlight)
        packer.add(0b0001, length: 4)
    }

    public var description: String {
        "<14-step e-stop \(direction)\(headlight ? " FL" : "")>"
    }
}
