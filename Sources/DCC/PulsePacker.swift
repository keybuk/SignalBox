//
//  PulsePacker.swift
//  DCC
//
//  Created by Scott James Remnant on 5/19/18.
//

import Foundation

/// Serialized PWM input from logical bits.
///
/// `PulsePacker` creates arrays of platform words containing the bit representation of the pulses
/// required to output the logical bits from the values packed into it.
///
/// Put simply, when initialized with a `PulseTiming.pulseWidth` of 1ms, a packed 1 bit value
/// results in an output of 58 consecutive 1 bits, followed by 58 consecutive 0 bits, representing
/// the PWM pulse of the duration expected.
public struct PulsePacker : Packer, CustomDebugStringConvertible {
    
    public typealias Word = UInt32
    
    /// Timing values used for conversion.
    public var timing: PulseTiming

    /// Packed words.
    public var words: [Word]
    
    /// Number of bits remaining in the final word.
    public var bitsRemaining = 0
    
    public init(timing: PulseTiming) {
        self.timing = timing
        words = []
    }
    
    public var debugDescription: String {
        let bitsString = words.map({ $0.binaryString }).joined(separator: " ")
        return "<\(type(of: self)) \(bitsString), remaining: \(bitsRemaining)>"
    }
    
    /// Duration in microseconds of the output.
    public var duration: Float {
        let numberOfBits = words.count * Word.bitWidth - bitsRemaining
        return Float(numberOfBits) * timing.pulseWidth
    }

    /// Add pulses for the contents of a value.
    ///
    /// The length of the significant part of value`` is given in `length`. Only the least
    /// significant `length` bits from `value` are used to create the output pulses.
    ///
    /// New words are added whenever necessary to contain all of the fields, and fields may span
    /// word boundaries, and be multiple words in length.
    ///
    /// - parameters:
    ///   - value: value to add.
    ///   - length: length of the field.
    public mutating func add<T>(_ value: T, length: Int) where T : FixedWidthInteger {
        assert(length > 0, "length must be greater than 0")
        assert(length <= T.bitWidth, "length must be less than \(T.bitWidth)")
        
        // Convert each input bit; there's no shortcut here for counting consecutive bits because
        // we always have to output a block of 1s and 0s for each one anyway.
        for offset in 0..<length {
            let bit = value >> (length - offset - 1) & 1
            let pulseLength = bit == 0 ? timing.zeroBitLength : timing.oneBitLength
            
            add(pulseLength: pulseLength, high: true)
            add(pulseLength: pulseLength, high: false)

        }
    }
    
    /// Add the bits corresponding to single pulse phase.
    ///
    /// - parameters:
    ///   - pulseLength: length in bits of the pulse.
    ///   - high: `true` if the bits should be 1, `false` if 0.
    mutating func add(pulseLength: Int, high: Bool) {
        var pulseLength = pulseLength
        repeat {
            if bitsRemaining < 1 {
                words.append(0)
                bitsRemaining = Word.bitWidth
            }
            
            let chunkLength = min(pulseLength, bitsRemaining)
            bitsRemaining -= chunkLength
            pulseLength -= chunkLength

            if high {
                let bits: Word = ~(~0 << chunkLength)
                words[words.index(before: words.endIndex)] |= bits << bitsRemaining
            }
        } while pulseLength > 0
    }
    
}
