//
//  Bitstream.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

/// Bitstream serializes logical DCC packets into a physical bitstream.
///
/// The physical bitstream assumes that bits have an individual duration of 14.5µs. A physical bit value of 1 means the output will be +3V for the duration, while a physical bit value of 0 means it will be 0V for the duration. Given these constraints, the resulting stream conforms to NMRA S-9.1.
///
/// Individual words within the bitstream are msb-aligned according to `wordSize`, but may contain fewer bits as denoted by their `size` payload. The output should not be padded.
///
/// Additional events such as the RailCom cutout period, and a debug packet period, are included in the bitstream. These markers are placed in the stream prior to the data to which they should be synchronized.
///
/// This bitstream can be passed to a `Driver`.
public struct Bitstream : Collection {
    
    /// Size of words.
    ///
    /// Generally the platform's word size, but can be overriden at initialization for testing purposes.
    let wordSize: Int
    
    public init(wordSize: Int) {
        self.wordSize = wordSize
    }
    
    public init() {
        self.wordSize = MemoryLayout<Int>.size * 8
    }

    /// Event than can occur within the DCC bitstream.
    public enum Event {
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
    }

    /// Events generated from the input.
    var events: [Event] = []
    
    // Conformance to Collection.
    // Forward to the private `events` array.
    public var startIndex: Array<Event>.Index { return events.startIndex }
    public var endIndex: Array<Event>.Index { return events.endIndex }
    
    public func index(after i: Array<Event>.Index) -> Array<Event>.Index {
        return events.index(after: i)
    }
    
    public subscript(index: Array<Event>.Index) -> Event {
        return events[index]
    }
    
    /// Append an event.
    ///
    /// - Parameters:
    ///   - event: event to append.
    public mutating func append(_ event: Event) {
        events.append(event)
    }
    
    /// Append logical bits.
    ///
    /// Logical bits represent the DCC signal. A logical bit value of 1 has a duration of +3V for 58µs, followed by 0V for the same duration; while a logical bit value of 0 has a duration of +3V for 101.5µs, followed by 0V for the same duration.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - bit: logical bit to append, must be the value 1 or 0.
    ///
    /// - Note:
    ///   NMRA S-9.1 recommends a minimum duration of 100µs for a logical 0 bit. We use a slightly longer value because it allows for much more efficient usage of the PWM and DMA hardware. This is permitted as the standard allows the duration to be in the range 99—9,900µs.
    public mutating func append(logicalBit bit: Int) {
        switch bit {
        case 1:
            append(physicalBits: 0b11110000, count: 8)
        case 0:
            append(physicalBits: 0b11111110000000, count: 14)
        default:
            assertionFailure("Bit must be 1 or 0")
        }
    }
    
    /// Append physical bits.
    ///
    /// Physical bits are the input to the PWM, with a duration of 14.5µs. A physical bit value of 1 means the mapped GPIO will be +3V for the duration, while a physical bit value of 0 means it will be 0V for the duration.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Parameters:
    ///   - bits: physical bits to be added, this is an LSB-aligned value.
    ///   - count: number of right-most bits from `bits` to be added.
    public mutating func append(physicalBits bits: Int, count: Int) {
        var count = count

        // Where the last events type is already data, remove and extend it.
        if case let .data(word: word, size: size)? = events.last,
            size < wordSize
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
            // For testing, wordSize can be defined as shorter than the size of Int on this platform; so be sure to mask out the left-most excess part.
            var word = bits << (wordSize - count)
            if wordSize < MemoryLayout<Int>.size * 8 {
                word &= (1 << wordSize) - 1
            }
            
            events.append(.data(word: word, size: count))
        }
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
        
        appendRailComCutout()

        // If we were debugging this packet, clear the marker for that too; thus the debug duration includes the full packet, and the RailCom cutout.
        if debug {
            append(.debugEnd)
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
                append(logicalBit: (byte >> (7 - bit)) & 0x1)
            }
        }

        // Packet End Bit: 1 x 1-bit.
        append(logicalBit: 1)
    }
    
    /// Append a RailCom cutout.
    ///
    /// The RailCom cutout is a period of logical 1 bits, combined with the `.railComCutoutStart` and `.railComCutoutEnd` events at points to produce the correct timings. If the RailCom cutout signal is ignored, this thus simply extends the preamble of the following command without interrupting the DCC signal.
    ///
    /// If the last event is `.data` with a `size` less than `wordSize`, it will be extended to include the new bits, otherwise a new `.data` is appended.
    ///
    /// - Note:
    ///   NMRA S-9.1 specifies that the DCC signal must continue for at least 26µs after the packet end bit, which delays the time for the start of the RailCom cutout. NMRA S-9.3.2 further specifies a maximum delay of 32µs. Since physical bits in the stream are 14.5µs, two bits are used to give a delay of 29µs.
    ///
    ///   For the duration of the cutout, NMRA S-9.3.2 provides a valid range of 454–488µs after the packet end bit, and thus including the cutout delay. A total of 32 physical bits are used—2 in the delay above, 30 in the remainder—giving a total cutout duration of 464µs.
    public mutating func appendRailComCutout() {
        append(physicalBits: 0b11, count: 2)
        append(.railComCutoutStart)
        append(physicalBits: 0b110000111100001111000011110000, count: 30)
        append(.railComCutoutEnd)
    }

}
