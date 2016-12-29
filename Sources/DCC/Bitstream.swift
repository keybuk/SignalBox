//
//  Bitstream.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

/// Bitstream serializes logical DCC packets into a physical bitstream.
///
/// Each physical bit within the bitstream has a duration of `bitDuration`, passed during initialization. A physical bit value of 1 means the output will be +3.3V for the duration, while a physical bit value of 0 means it will be 0V for the duration.
///
/// The number of physical one or zero bits is selected to conform to the constraints specified by NMRA S-9.1.
///
/// Individual words within the bitstream are msb-aligned, but may contain fewer bits as denoted by their `size` payload. The output should not be padded.
///
/// Additional events such as the RailCom cutout period, and a debug packet period, are included in the bitstream. These markers are placed in the stream prior to the data to which they should be synchronized. The durations of the RailCom cutout confirm to NMRA S-9.3.2.
///
/// This bitstream can be passed to a `Driver`.
public struct Bitstream : Collection {
    
    /// Recommended duration in microseconds of the high and low parts of a one bit.
    ///
    /// - Note:
    ///   NMRA S-9.1 defines this as the nominal duration for a one bit.
    public let oneBitDuration: Float = 58
    
    /// Minimum permitted duration in microseconds of the high and low parts of a one bit.
    ///
    /// - Note:
    ///   NMRA S-9.1 defines this as the minimum permitted duration for the command station to send, while allowing decoders to be less strict.
    public let oneBitMinimumDuration: Float = 55
    
    /// Maximum permitted duration in microseconds of the high and low parts of a one bit.
    ///
    /// - Note:
    ///   NMRA S-9.1 defines this as the maximum permitted duration for the command station to send, while allowing decoders to be less strict.
    public let oneBitMaximumDuration: Float = 61
    
    /// Recommended duration in microseconds of the high and low parts of a zero bit.
    ///
    /// - Note:
    ///   NMRA S-9.1 defines this as the nominal "greater than or equal to" duration for a zero bit.
    public let zeroBitDuration: Float = 100
    
    /// Minimum permitted duration in microseconds of the high and low parts of a zero bit.
    ///
    /// - Note:
    ///   NMRA S-9.1 defines this as the minimum permitted duration for the command station to send, while allowing decoders to be less strict.
    public let zeroBitMinimumDuration: Float = 95
    
    /// Maximum permitted duration in microseconds of the high and low parts of a zero bit.
    ///
    /// - Note:
    ///   NMRA S-9.1 specifies: Digital Command Station components shall transmit "0" bits with each part of the bit having a duration of between 95 and 9900 microseconds with the total bit duration of the "0" bit not exceeding 12000 microseconds.
    ///
    ///   Since our transmission parts are always equal in length, this is half of the latter value.
    public let zeroBitMaximumDuration: Float = 6000
    
    /// Minimum permitted duration in microseconds before the start of the RailCom cutout.
    ///
    /// No nomimal duration is defined by the standard, so this is the target we use when calculating bit lengths.
    ///
    /// - Note:
    ///   NMRA S-9.1 specifies that the DCC signal must continue for at least 26µs after the packet end bit, which delays the time for the start of the RailCom cutout.
    public let railComCutoutStartMinimumDuration: Float = 26

    /// Maximum permitted duration in microseconds before the start of the RailCom cutout.
    ///
    /// - Note:
    ///   Specified in NMRA S-9.3.2.
    public let railComCutoutStartMaximumDuration: Float = 32

    /// Minimum permitted duration in microseconds of the RailCom cutout.
    ///
    /// No nomimal duration is defined by the standard, so this is the target we use when calculating bit lengths.
    ///
    /// - Note:
    ///   Specified in NMRA S-9.3.2 and is measured from the end of the Packet End Bit, and thus includes the delay before the start of the RailCom cutout.
    public let railComCutoutEndMinimumDuration: Float = 454
    
    /// Maximum permitted duration in microseconds of the RailCom cutout.
    ///
    /// - Note:
    ///   Specified in NMRA S-9.3.2 and is measured from the end of the Packet End Bit, and thus includes the delay before the start of the RailCom cutout.
    public let railComCutoutEndMaximumDuration: Float = 488

    /// Duration in microseconds of a single physical bit.
    public let bitDuration: Float
    
    /// Length in physical bits of the high and low parts of a one bit.
    ///
    /// This is calculated during initialization based on `bitDuration`.
    public let oneBitLength: Int
    
    /// Length in physical bits of the high and low parts of a zero bit.
    ///
    /// This is calculated during initialization based on `bitDuration`.
    public let zeroBitLength: Int

    /// Length in physical bits of the delay before the start of the RailCom cutout.
    ///
    /// This is calculated during initialization based on `bitDuration`.
    public let railComDelayLength: Int

    /// Length in physical bits of the RailCom cutout.
    ///
    /// This bit length is measured from the end of the Packet End Bit, and thus includes the bits specified in `railComDelayLength`. It is calculated during initialization based on `bitDuration`.
    public let railComCutoutLength: Int

    /// Size of words.
    ///
    /// Generally the platform's word size, but can be overriden at initialization for testing purposes.
    let wordSize: Int
    
    init(bitDuration: Float, wordSize: Int) {
        self.bitDuration = bitDuration
        self.wordSize = wordSize
        
        oneBitLength = Int((oneBitDuration - 1.0) / bitDuration) + 1
        zeroBitLength = Int((zeroBitDuration - 1.0) / bitDuration) + 1
        
        railComDelayLength = Int((railComCutoutStartMinimumDuration - 1.0) / bitDuration) + 1
        railComCutoutLength = Int((railComCutoutEndMinimumDuration - 1.0) / bitDuration) + 1

        // Sanity check the lengths.
        assert(((Float(oneBitLength) * bitDuration) >= oneBitMinimumDuration) && ((Float(oneBitLength) * bitDuration) <= oneBitMaximumDuration), "Duration of one bit would be \(Float(oneBitLength) * bitDuration)µs which is outside the valid range \(oneBitMinimumDuration)–\(oneBitMaximumDuration)µs")
        assert(((Float(zeroBitLength) * bitDuration) >= zeroBitMinimumDuration) && ((Float(zeroBitLength) * bitDuration) <= zeroBitMaximumDuration), "Duration of zero bit would be \(Float(zeroBitLength) * bitDuration)µs which is outside the valid range \(zeroBitMinimumDuration)–\(zeroBitMaximumDuration)µs")
        
        assert(((Float(railComDelayLength) * bitDuration) >= railComCutoutStartMinimumDuration) && ((Float(railComDelayLength) * bitDuration) <= railComCutoutStartMaximumDuration), "Duration of pre-RailCom cutout delay would be \(Float(railComDelayLength) * bitDuration)µs which is outside the valid range \(railComCutoutStartMinimumDuration)–\(railComCutoutStartMaximumDuration)µs")
        assert(((Float(railComCutoutLength) * bitDuration) >= railComCutoutEndMinimumDuration) && ((Float(railComCutoutLength) * bitDuration) <= railComCutoutEndMaximumDuration), "Duration of RailCom cutout would be \(Float(railComCutoutLength) * bitDuration)µs which is outside the valid range \(railComCutoutEndMinimumDuration)–\(railComCutoutEndMaximumDuration)µs")
    }
    
    public init(bitDuration: Float) {
        self.init(bitDuration: bitDuration, wordSize: MemoryLayout<Int>.size * 8)
    }

    /// Events generated from the input.
    private var events: [BitstreamEvent] = []
    
    // Conformance to Collection.
    // Forward to the private `events` array.
    public var startIndex: Array<BitstreamEvent>.Index { return events.startIndex }
    public var endIndex: Array<BitstreamEvent>.Index { return events.endIndex }
    
    public func index(after i: Array<BitstreamEvent>.Index) -> Array<BitstreamEvent>.Index {
        return events.index(after: i)
    }
    
    public subscript(index: Array<BitstreamEvent>.Index) -> BitstreamEvent {
        return events[index]
    }
    
    /// Append an event.
    ///
    /// - Parameters:
    ///   - event: event to append.
    public mutating func append(_ event: BitstreamEvent) {
        events.append(event)
    }
    
    /// Append physical bits.
    ///
    /// Physical bits are the input to the PWM, with a duration of `bitDuration`. A physical bit value of 1 means the mapped GPIO will be +3V for the duration, while a physical bit value of 0 means it will be 0V for the duration.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - bits: physical bits to be added, this is an LSB-aligned value.
    ///   - count: number of right-most bits from `bits` to be added.
    public mutating func append(physicalBits bits: Int, count: Int) {
        assert(count <= wordSize, "cannot append more physical bits than the word size")
        var count = count
        
        // Where the last events type is already data, remove and extend it.
        if case let .data(word: word, size: size)? = events.last,
            size < wordSize,
            count > 0
        {
            // This is a little more complex because the values in `bits` are lsb-aligned while the values in `words` are msb-aligned, and we have to beware of one-fill when shifting to the right.
            let mask = (1 << (wordSize - size)) - 1
            let alignedBits = (bits << (wordSize - count)) >> size

            events.removeLast()
            events.append(.data(word: word | (alignedBits & mask), size: Swift.min(size + count, wordSize)))
            
            count -= wordSize - size
        }
        
        // If any bits remain, add a new word with them.
        if count > 0 {
            var word = bits << (wordSize - count)
            
            // For testing, wordSize can be defined as shorter than the size of Int on this platform; so be sure to mask out the left-most excess part.
            if wordSize < MemoryLayout<Int>.size * 8 {
                word &= ~(~0 << wordSize)
            }
            
            events.append(.data(word: word, size: count))
        }
    }
    
    /// Append a repeating physical bits.
    ///
    /// Physical bits are the input to the PWM, with a duration of `bitDuration`. A physical bit value of 1 means the mapped GPIO will be +3V for the duration, while a physical bit value of 0 means it will be 0V for the duration.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - bit: physical bit to be added.
    ///   - count: number of repeated `bit` to be added.
    public mutating func append(repeatingPhysicalBit bit: Int, count: Int) {
        var count = count
        
        // Where the last events type is already data, remove and extend it.
        if case let .data(word: word, size: size)? = events.last,
            size < wordSize,
            count > 0
        {
            events.removeLast()

            let numberOfBits = Swift.min(count, wordSize - size)
            switch bit {
            case 1:
                let bits = ~(~0 << numberOfBits) << (wordSize - size - numberOfBits)
                events.append(.data(word: word | bits, size: size + numberOfBits))
            case 0:
                events.append(.data(word: word, size: size + numberOfBits))
                break
            default:
                assertionFailure("Bit must be 1 or 0")
            }

            count -= numberOfBits
        }
        
        // While any bits remain, add new words with them.
        while count > 0 {
            let numberOfBits = Swift.min(count, wordSize)
            switch bit {
            case 1:
                // Append `count` bits; use a short-cut if we're just filling an entire word to avoid the `x << wordSize` error.
                if numberOfBits < (MemoryLayout<Int>.size * 8) {
                    let bits = ~(~0 << numberOfBits) << (wordSize - numberOfBits)
                    events.append(.data(word: bits, size: numberOfBits))
                } else {
                    events.append(.data(word: ~0, size: numberOfBits))
                }
            case 0:
                events.append(.data(word: 0, size: numberOfBits))
                break
            default:
                assertionFailure("Bit must be 1 or 0")
            }
            
            count -= numberOfBits
        }
    }
    
    /// Append logical bits.
    ///
    /// Logical bits represent the DCC signal. A logical bit value of 1 has a duration of +3V for at least `oneBitDuration`, followed by 0V for the same duration; while a logical bit value of 0 has a duration of +3V for `zeroBitDuration`, followed by 0V for the same duration.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - bit: logical bit to append, must be the value 1 or 0.
    public mutating func append(logicalBit bit: Int) {
        switch bit {
        case 1:
            append(repeatingPhysicalBit: 1, count: oneBitLength)
            append(repeatingPhysicalBit: 0, count: oneBitLength)
        case 0:
            append(repeatingPhysicalBit: 1, count: zeroBitLength)
            append(repeatingPhysicalBit: 0, count: zeroBitLength)
        default:
            assertionFailure("Bit must be 1 or 0")
        }
    }
    
    /// Append a DCC preamble.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - length: number of preamble bits (default: 14).
    ///
    /// - Note:
    ///   NMRA S-9.2 recommends that the preamble consist of a minimum of 14 bits. For service mode programming, NMRA S-9.2.3 specifies a long preamble of 20 bits.
    public mutating func appendPreamble(length: Int = 14) {
        for _ in 0..<length {
            append(logicalBit: 1)
        }
    }
    
    /// Append a RailCom cutout.
    ///
    /// The RailCom cutout is a period of logical 1 bits, combined with the `.railComCutoutStart` and `.railComCutoutEnd` events at points to produce the correct timings. If the RailCom cutout signal is ignored, this thus simply extends the preamble of the following command without interrupting the DCC signal.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - debug: `true` if the debug GPIO pin should be cleared at the end of the RailCom cutout.
    public mutating func appendRailComCutout(debug: Bool = false) {
        // Pad out the RailCom cutout to an exact multiple of logical one bit sizes (twice `oneBitLength`).
        // Step through each part (high or low) and output the appropriate piece.
        let railComLength = (oneBitLength * 2) * ((railComCutoutLength - 1) / (oneBitLength * 2) + 1)
        for offset in stride(from: 0, to: railComLength, by: oneBitLength) {
            let physicalBit = (offset / oneBitLength) % 2 == 0 ? 1 : 0
            let nextOffset = offset + oneBitLength
            if (offset..<nextOffset).contains(railComDelayLength) {
                // RailCom delay ends within this part, splice it and place the start marker.
                append(repeatingPhysicalBit: physicalBit, count: railComDelayLength - offset)
                append(.railComCutoutStart)
                append(repeatingPhysicalBit: physicalBit, count: oneBitLength - (railComDelayLength - offset))
            } else if (offset...nextOffset).contains(railComCutoutLength) {
                // RailCom cutout ends within or immediately after this part, splice it and place the end marker.
                append(repeatingPhysicalBit: physicalBit, count: railComCutoutLength - offset)
                append(.railComCutoutEnd)
                if debug {
                    append(.debugEnd)
                }
                append(repeatingPhysicalBit: physicalBit, count: oneBitLength - (railComCutoutLength - offset))
            } else {
                // Output the high or low part of a logical one bit.
                append(repeatingPhysicalBit: physicalBit, count: oneBitLength)
            }
        }
    }
    
    /// Append a DCC packet.
    ///
    /// The contents of the packet are appended along with the packet start bit, data byte start bits, and packet end bit.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - packet: DCC packet to be added, including the error detection data byte.
    public mutating func append(packet: Packet) {
        // Each packet byte, starting with the first, is preceeded by a 0 bit.
        for byte in packet.bytes {
            append(logicalBit: 0)
            
            for bit in 0..<8 {
                append(logicalBit: (byte >> (7 - bit)) & 0b1)
            }
        }
        
        // Packet End Bit: 1 x 1-bit.
        append(logicalBit: 1)
    }
    
    /// Append a DCC packet for use in Operations Mode.
    ///
    /// An operations mode packet consists of a 14-bit preamble, followed by the packet and a RailCom cutout.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - packet: individual bytes for the packet, including the error detection data byte.
    ///   - debug: `true` if the debug GPIO pin should be raised during this packet transmission and RailCom cutout.
    public mutating func append(operationsModePacket packet: Packet, debug: Bool = false) {
        appendPreamble()
        
        // If we are debugging this packet, place a marker at the end of the preamble and before the packet start bit.
        if debug {
            append(.debugStart)
        }
        
        append(packet: packet)
        
        appendRailComCutout(debug: debug)
    }

}

/// Event than can occur within the DCC bitstream.
public enum BitstreamEvent : Equatable {
    /// Physical bit data for PWM input consisting of an msb-aligned `word` of `size` bits, which may be less than `wordSize`.
    case data(word: Int, size: Int)
    
    /// Indicates that the RailCom cutout period should begin aligned with the start of the next `.data`.
    case railComCutoutStart
    
    /// Indicates that the RailCom cutout period should end aligned with the start of the next `.data`.
    case railComCutoutEnd
    
    /// Indicates that the debug packet period should begin aligned with the start of the next `.data`.
    case debugStart
    
    /// Indicates that the debug packet period should end aligned with the start of the next `.data`.
    case debugEnd
    
    public static func ==(lhs: BitstreamEvent, rhs: BitstreamEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.data(lhsWord, lhsSize), .data(rhsWord, rhsSize)):
            return lhsWord == rhsWord && lhsSize == rhsSize
        case (.railComCutoutStart, .railComCutoutStart):
            return true
        case (.railComCutoutEnd, .railComCutoutEnd):
            return true
        case (.debugStart, .debugStart):
            return true
        case (.debugEnd, .debugEnd):
            return true
        default:
            return false
        }
    }

}

