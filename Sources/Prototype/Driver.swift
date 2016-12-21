//
//  Driver.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/20/16.
//
//

struct Driver {
    
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
    
    func go(bitstream: Bitstream) {
        var range = 0
        var delayedEvents: [(Int, Bitstream.Event)] = []
        var addresses: [Int] = []
        var repeating = false
        
        loop: repeat {
            var dataAddress = 0
            var nextAddress = 0
            for event in bitstream.events {
                switch event {
                case let .data(words: words, lastWordSize: lastWordSize):
                    if !repeating {
                        print(String(dataAddress) + "::")
                        addresses.append(dataAddress)
                        dataAddress += 1
                    } else {
                        nextAddress += 1
                    }

                    // Slice up the words list, if necessary.
                    var slices: [ArraySlice<Int>] = []
                    
                    var lastSlice = 0
                    
                    if words.count > 1 && range != bitstream.wordSize {
                        slices.append(words[lastSlice..<1])
                        lastSlice = 1
                    }
                    
                    for (delay, _) in delayedEvents {
                        if delay < words.count {
                            if delay > lastSlice {
                                slices.append(words[lastSlice..<delay])
                                lastSlice = delay
                            }
                        } else {
                            break
                        }
                    }
                    
                    slices.append(words[lastSlice..<words.count])
                    
                    for (index, slice) in slices.enumerated() {
                        let lastWordSize = index == slices.count - 1 ? lastWordSize : bitstream.wordSize
                        printData([Int](slice), wordSize: bitstream.wordSize, lastWordSize: lastWordSize)
                        if range != lastWordSize {
                            print("RANGE " + String(lastWordSize))
                            range = lastWordSize
                        }
                        
                        delayedEvents = delayedEvents.map({ ($0 - slice.count, $1) })
                        
                        while case let (delay, event)? = delayedEvents.first,
                            delay == 0
                        {
                            delayedEvents.removeFirst()
                            
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
                        
                        print()
                    }
                    
                    if repeating && delayedEvents.count == 0 {
                        print("---> " + String(addresses[nextAddress]))
                        break loop
                    }

                    // possibilities here:
                    //
                    // all words go in one control block
                    // all words go in one control block, followed by a range
                    // first word goes in one, followed by a range, followed by the rest, followed by a range
                    
                    // some words go in a control block, followed by a gpio change

                    // split words based on the following:
                    //   index != last && range != bitstream.wordSize
                    //   index is a delay in delayedEvents
                    
                default:
                    delayedEvents.append((eventDelay, event))
                }
            }
        
            print(delayedEvents)
            repeating = true
        } while delayedEvents.count > 0
        
        // data becomes a DMAControlBlock with a total length of the number of words
        // if the current range is not 32, it has to instead be a CB for the first word, followed by a range set CB to 32, followed by a CB for the remainder
        // if the lastWordSize is not 32, it has to be followed by a range set CB to the lastWordSize
        
        // other events are pushed into a list, and marked as requiring two words
        // each time we process data, for each word, we decrement the required count for everything in the list
        // when any item reaches zero, we stop the CB, follow it with gpio set CB(s)s for the events, and then resume with CB for the remainder
        
        // the above requires an array of control blocks, bus address of it; array of data, bus address of that; gpio pins for railcom and debug, bus address of the gpio; and bus address of the pwm

        
    }
    
}
