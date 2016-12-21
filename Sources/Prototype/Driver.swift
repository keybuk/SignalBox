//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

/// Driver utilizes the Raspberry Pi hardware to output a DCC bitstream.
///
/// The PWM is used to generate the basic bitstream, with the FIFO sourced from memory by the DMA engine. Combining the two in this way reduces the memory bandwidth by a factor of 32, since the PWM can receive 32 physical bits with each DMA transfer.
///
/// Since there are not sufficient PWM channels, GPIOs are used directly from the DMA engine for the RailCom cutout, and the debug signal. Testing revealed that the control blocks to adjust the GPIOs must be synchronized with the second DREQ after the one for the word they are to be synchronized with, to allow that word to pass through the FIFO and into the PWM hardware. Much of the logic of this class is handling that delaying compared to the bitstream, including across the loop at the end of the data.
///
/// In addition, since the DREQ is synchronized to PWM word boundaries, it is necessary to regularly use the DMA engine to adjust the Range register of the PWM so a GPIO can be raised or lowered at the correct physical bit boundary, which may not otherwise fall on a word boundary. Testing revealed that the control block for this Range register change must be synchronized with the first DREQ after the one for the word it is to adjust. The need to shortern a word is already conveyed in the bitstream through the `size` payload.
struct Driver {
    
    enum DriverError: Error {
        case infiniteLoop
    }
    
    let eventDelay = 2
    
    func printData(_ words: [Int], wordSize: Int, lastWordSize: Int) {
        for (index, word) in words.enumerated() {
            var wordstr = String(UInt(bitPattern: word), radix: 2)
            wordstr = String(repeating: "0", count: wordSize - wordstr.characters.count) + wordstr
            
            if index == words.count - 1 {
                wordstr.removeSubrange(wordstr.index(wordstr.startIndex, offsetBy: lastWordSize)..<wordstr.endIndex)
            }
            
            for i in stride(from: (wordstr.characters.count - 1) / 8, to: 0, by: -1) {
                wordstr.insert(" ", at: wordstr.index(wordstr.startIndex, offsetBy: i * 8))
            }

            print(wordstr)
        }
    }
    
    func dueDelayedEvents(_ delayedEvents: inout [(Int, Bitstream.Event)]) -> [Bitstream.Event] {
        let oldDelayedEvents = delayedEvents
        delayedEvents.removeAll()
        
        var dueEvents: [Bitstream.Event] = []

        for (delay, event) in oldDelayedEvents {
            if delay == 1 {
                dueEvents.append(event)
            } else {
                delayedEvents.append((delay - 1, event))
            }
        }
        
        return dueEvents
    }
    
    // outputs from this are:
    // 1. words.
    // 2. ranges.
    // 3. gpio sets.
    func go(bitstream: Bitstream) throws {
        var range = 0
        var words: [Int] = []
        var delayedEvents: [(Int, Bitstream.Event)] = []
        var addresses: [Int: Int] = [:]
        var address = 0

        var repeating = false
        loop: repeat {
            var laggingEvents = delayedEvents
            delayedEvents = []
            
            var dataIndex = 0
            for event in bitstream {
                switch event {
                case let .data(word: word, size: size):
                    if repeating && laggingEvents.isEmpty && words.isEmpty,
                        let address = addresses[dataIndex]
                    {
                        print("--> " + String(address))
                        break loop
                    }
                    
                    words.append(word)

                    var dueEvents: [Bitstream.Event] = []
                    dueEvents.append(contentsOf: dueDelayedEvents(&laggingEvents))
                    dueEvents.append(contentsOf: dueDelayedEvents(&delayedEvents))
                    
                    if size != range || !dueEvents.isEmpty {
                        let rootIndex = dataIndex - words.count + 1
                        print(String(address) + "::")

                        printData(words, wordSize: bitstream.wordSize, lastWordSize: size)
                        words = []

                        addresses[rootIndex] = address
                        address += 1
                    }
                
                    if size != range {
                        print("RANGE " + String(size))
                        range = size
                    }

                    for event in dueEvents {
                        switch event {
                        case .railComCutoutStart:
                            print("RAILCOM START")
                        case .railComCutoutEnd:
                            print("RAILCOM END")
                        case .debugStart:
                            print("DEBUG START")
                        case .debugEnd:
                            print("DEBUG END")
                        default:
                            print("hmm")
                        }
                    }
                    
                    dataIndex += 1
                default:
                    delayedEvents.append((eventDelay, event))
                }
            }
            
            print(delayedEvents)
            if repeating {
                throw DriverError.infiniteLoop
            } else {
                repeating = true
            }
        } while !delayedEvents.isEmpty

        if !words.isEmpty {
            printData(words, wordSize: bitstream.wordSize, lastWordSize: range)
        }

        // data becomes a DMAControlBlock with a total length of the number of words
        // if the current range is not 32, it has to instead be a CB for the first word, followed by a range set CB to 32, followed by a CB for the remainder
        // if the lastWordSize is not 32, it has to be followed by a range set CB to the lastWordSize
        
        // other events are pushed into a list, and marked as requiring two words
        // each time we process data, for each word, we decrement the required count for everything in the list
        // when any item reaches zero, we stop the CB, follow it with gpio set CB(s)s for the events, and then resume with CB for the remainder
        
        // the above requires an array of control blocks, bus address of it; array of data, bus address of that; gpio pins for railcom and debug, bus address of the gpio; and bus address of the pwm

        
    }
    
}
