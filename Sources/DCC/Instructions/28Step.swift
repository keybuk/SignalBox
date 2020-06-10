//
//  28Step.swift
//  DCC
//
//  Created by Scott James Remnant on 11/16/19.
//

import Foundation

/// 28-step Speed and Direction instruction
///
/// This is used when bit 1 of CV#29 has a value of one, otherwise `Speed14Step` should be used.
///
/// - Note:
///   Sends a Speed and Direction Instruction as defined in NMRA S-9.2.1 C, compatible with the Baseline
///   Speed and Direction Packet defined in NMRA S-9.2 B.
public struct Speed28Step : Packable, CustomStringConvertible {
    /// Direction of travel.
    public var direction: Direction

    /// Speed of travel.
    ///
    /// Clamped to the range 0...28.
    @Clamping(0...28)
    public var speed: Int = 0

    public init(_ speed: Int, direction: Direction) {
        self.direction = direction
        self.speed = speed
    }

    public func add<T>(into packer: inout T) where T : Packer {
        switch direction {
        case .reverse:
            packer.add(0b010, length: 3)
        case .forward:
            packer.add(0b011, length: 3)
        }

        if speed > 0 {
            let adjustedSpeed = speed + 3
            packer.add(adjustedSpeed, length: 1)
            packer.add(adjustedSpeed >> 1, length: 4)
        } else {
            packer.add(0b0, length: 1)
            packer.add(speed, length: 4)
        }
    }

    public var description: String {
        "<28-step speed \(direction) \(speed)>"
    }
}

/// 28-step Stop instruction
///
/// Equivalent to `Speed28Step(0)` with the option of specidfying no change in `direction`,
/// the decoder will come to stop based on its own configuration.
///
/// This is used when bit 1 of CV#29 has a value of one, otherwise `Speed14Step` should be used.
///
/// - Note:
///   Sends a Speed and Direction Instruction as defined in NMRA S-9.2.1 C, compatible with the Baseline
///   Speed and Direction Packet defined in NMRA S-9.2 B.
public struct Stop28Step : Packable, CustomStringConvertible {
    /// Direction of travel while stopping.
    ///
    /// Set to `nil` to ignore and use the current direction.
    public var direction: Direction?

    public init(direction: Direction? = nil) {
        self.direction = direction
    }

    public func add<T>(into packer: inout T) where T : Packer {
        switch direction {
        case .reverse?:
            packer.add(0b010, length: 3)
        case .forward?:
            packer.add(0b011, length: 3)
        case nil:
            // Use the forward command when ignoring.
            packer.add(0b011, length: 3)
        }

        packer.add(direction == nil)
        packer.add(0b0000, length: 4)
    }

    public var description: String {
        "<28-step stop\(direction != nil ? " \(direction!)" : "")>"
    }
}

/// 28-step Emergency Stop instruction
///
/// The decoder immediately stops delivering power to the motor.
///
/// This is used when bit 1 of CV#29 has a value of one, otherwise `Speed14Step` should be used.
///
/// - Note:
///   Sends a Speed and Direction Instruction as defined in NMRA S-9.2.1 C, compatible with the Baseline
///   Speed and Direction Packet defined in NMRA S-9.2 B.
public struct EmergencyStop28Step : Packable, CustomStringConvertible {
    /// Direction of travel while stopping.
    ///
    /// Set to `nil` to ignore and use the current direction.
    public var direction: Direction?

    public init(direction: Direction? = nil) {
        self.direction = direction
    }

    public func add<T>(into packer: inout T) where T : Packer {
        switch direction {
        case .reverse?:
            packer.add(0b010, length: 3)
        case .forward?:
            packer.add(0b011, length: 3)
        case nil:
            // Use the forward command when ignoring.
            packer.add(0b011, length: 3)
        }

        packer.add(direction == nil)
        packer.add(0b0001, length: 4)
    }

    public var description: String {
        "<28-step e-stop\(direction != nil ? " \(direction!)" : "")>"
    }
}
