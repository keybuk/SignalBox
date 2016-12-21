//
//  Bitstream.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

class Bitstream {
    
    let wordSize: Int
    
    init(wordSize: Int =  MemoryLayout<Int>.size * 8) {
        self.wordSize = wordSize
    }

    enum Event {
        /// Physical bit data for PWM input consisting of msb-aligned `words`, where the last word in the set has the size `lastWordSize` and may be less than `wordSize`.
        case data(words: [Int], lastWordSize: Int)
        
        /// Indicates that the RailCom cutout period should begin aligned with the start of the next data word.
        case railComCutoutStart
        
        /// Indicates that the RailCom cutout period should end aligned with the start of the next data word.
        case railComCutoutEnd
        
        /// Indicates that the debug packet period should begin aligned with the start of the next data word.
        case debugStart
        
        /// Indicates that the debug packet period should end aligned with the start of the next data word.
        case debugEnd
    }

    var events: [Event] = []
    
    /// Adds logical bits to `events`.
    ///
    /// Logical bits represent the DCC signal. A logical bit value of 1 has a duration of +3V for 58µs, followed by 0V for the same duration; while a logical bit value of 0 has a duration of +3V for 101.5µs, followed by 0V for the same duration.
    ///
    /// If the last event in `events` is `.data` it will be extended to include the new bits, otherwise a new `.data` event is added to `events`.
    ///
    /// - Parameters:
    ///   - bit: logical bit to be added, must be the value 1 or 0.
    ///
    /// - Note:
    ///   NMRA S-9.1 recommends a minimum duration of 100µs for a logical 0 bit. We use a slightly longer value because it allows for much more efficient usage of the PWM and DMA hardware. This is permitted as the standard allows the duration to be in the range 99—9,900µs.
    func addLogicalBit(_ bit: Int) {
        switch bit {
        case 1:
            addPhysicalBits(0b11110000, count: 8)
        case 0:
            addPhysicalBits(0b11111110000000, count: 14)
        default:
            fatalError("Bit must be 1 or 0")
        }
    }
    
    /// Adds physical bits to `events`.
    ///
    /// Physical bits are the input to the PWM, with a duration of 14.5µs. A physical bit value of 1 means the mapped GPIO will be +3V for the duration, while a physical bit value of 0 means it will be 0V for the duration.
    ///
    /// If the last event in `events` is `.data` it will be extended to include the new bits, otherwise a new `.data` event is added to `events`.
    ///
    /// - Parameters:
    ///   - bits: physical bits to be added, this is an LSB-aligned value.
    ///   - count: number of right-most bits from `bits` to be added.
    func addPhysicalBits(_ bits: Int, count: Int) {
        var words: [Int] = []
        var lastWordSize = wordSize
        
        // Where the last events type is already data, remove and extend it.
        if case let .data(words: oldWords, lastWordSize: oldLastWordSize)? = events.last {
            events.removeLast()

            words = oldWords
            lastWordSize = oldLastWordSize
        }
        
        // If the last serialized word is not yet full, add as many bits as we can to the end of it.
        var remainingCount = count
        if lastWordSize < wordSize {
            guard let lastWord = words.popLast() else { fatalError("Should always be a last word") }
            
            // This is a little more complex because the values in `bits` are lsb-aligned while the values in `words` are msb-aligned, and we have to beware of one-fill when shifting to the right.
            let mask = (1 << (wordSize - lastWordSize)) - 1
            let alignedBits = (bits << (wordSize - remainingCount)) >> lastWordSize
            words.append(lastWord | (alignedBits & mask))
            
            if lastWordSize + remainingCount <= wordSize {
                lastWordSize += remainingCount
                remainingCount = 0
            } else {
                remainingCount = lastWordSize + remainingCount - wordSize
            }
        }
        
        // If any bits remain, add a new word with them.
        if remainingCount > 0 {
            lastWordSize = remainingCount
            
            // For testing, wordSize can be defined as shorter than the size of Int on this platform; so be sure to mask out the left-most excess part.
            var alignedBits = bits << (wordSize - lastWordSize)
            if wordSize < MemoryLayout<Int>.size * 8 {
                alignedBits &= (1 << wordSize) - 1
            }
            
            words.append(alignedBits)
        }
        
        events.append(.data(words: words, lastWordSize: lastWordSize))
    }
    
    /// Add an event to `events`.
    ///
    /// - Parameters:
    ///   - event: event to be added to `events`.
    func addEvent(_ event: Event) {
        events.append(event)
    }
    
    /// Add a DCC packet for use in Operations Mode to `events`.
    ///
    /// An operations mode packet consists of a 14-bit preamble, followed by the packet and a RailCom cutout.
    ///
    /// If the last event in `events` is `.data` it will be extended to include the data of the new packet, otherwise only new events are added.
    ///
    /// - Parameters:
    ///   - packet: individual bytes for the packet, including the error detection data byte.
    ///   - debug: `true` if the debug GPIO pin should be raised during this packet transmission and RailCom cutout.
    func addOperationsModePacket(_ packet: Packet, debug: Bool = false) {
        addPreamble()
        
        // If we are debugging this packet, place a marker at the end of the preamble and before the packet start bit.
        if debug {
            addEvent(.debugStart)
        }
        
        addPacket(packet)
        
        addRailComCutout()

        // If we were debugging this packet, clear the marker for that too; thus the debug duration includes the full packet, and the RailCom cutout.
        if debug {
            addEvent(.debugEnd)
        }
    }
    
    /// Add a DCC preamble to `events`.
    ///
    /// If the last event in `events` is `.data` it will be extended to include the bits of the preamble, otherwise only new events are added.
    ///
    /// - Parameters:
    ///   - length: number of preamble bits (default: 14).
    ///
    /// - Note:
    ///   NMRA S-9.2 recommends that the preamble consist of a minimum of 14 bits. For service mode programming, NMRA S-9.2.3 specifies a long preamble of 20 bits.
    func addPreamble(length: Int = 14) {
        for _ in 0..<length {
            addLogicalBit(1)
        }
    }
    
    /// Add a DCC packet to `events`.
    ///
    /// The contents of the packet are added to `events` along with the packet start bit, data byte start bits, and packet end bit.
    ///
    /// If the last event in `events` is `.data` it will be extended to include the data of the new packet, otherwise only new events are added.
    ///
    /// - Parameters:
    ///   - packet: DCC packet to be added, including the error detection data byte.
    func addPacket(_ packet: Packet) {
        // Each packet byte, starting with the first, is preceeded by a 0 bit.
        for byte in packet.bytes {
            addLogicalBit(0)
            
            for bit in 0..<8 {
                addLogicalBit((byte >> (7 - bit)) & 0x1)
            }
        }

        // Packet End Bit: 1 x 1-bit.
        addLogicalBit(1)
    }
    
    /// Add a RailCom cutout to `events`.
    ///
    /// The RailCom cutout is a period of logical 1 bits, combined with the `.railComCutoutStart` and `.railComCutoutEnd` events at points to produce the correct timings. If the RailCom cutout signal is ignored, this thus simply extends the preamble of the following command without interrupting the DCC signal.
    ///
    /// If the last event in `events` is `.data` it will be extended to include the bits that delay the start of the cutout, otherwise only new events are added.
    ///
    /// - Note:
    ///   NMRA S-9.1 specifies that the DCC signal must continue for at least 26µs after the packet end bit, which delays the time for the start of the RailCom cutout. NMRA S-9.3.2 further specifies a maximum delay of 32µs. Since physical bits in the stream are 14.5µs, two bits are used to give a delay of 29µs.
    ///
    ///   For the duration of the cutout, NMRA S-9.3.2 provides a valid range of 454–488µs after the packet end bit, and thus including the cutout delay. A total of 32 physical bits are used—2 in the delay above, 30 in the remainder—giving a total cutout duration of 464µs.
    func addRailComCutout() {
        addPhysicalBits(0b11, count: 2)
        addEvent(.railComCutoutStart)
        addPhysicalBits(0b110000111100001111000011110000, count: 30)
        addEvent(.railComCutoutEnd)
    }

}
