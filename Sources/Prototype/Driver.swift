//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

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
            for event in bitstream.events {
                switch event {
                case let .data(word: word, size: size):
                    if repeating && laggingEvents.count == 0 && words.count == 0,
                        let address = addresses[dataIndex]
                    {
                        print("--> " + String(address))
                        break loop
                    }
                    
                    words.append(word)

                    var dueEvents: [Bitstream.Event] = []
                    dueEvents.append(contentsOf: dueDelayedEvents(&laggingEvents))
                    dueEvents.append(contentsOf: dueDelayedEvents(&delayedEvents))
                    
                    if size != range || dueEvents.count > 0 {
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
        } while delayedEvents.count > 0

        if words.count > 0 {
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
