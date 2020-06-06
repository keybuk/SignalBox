//
//  main.swift
//  TestGPIO
//
//  Created by Scott James Remnant on 5/27/20.
//

import Foundation
import Dispatch
import RaspberryPi

// Set GPIO18 to output.
let gpio = try! GPIO()
gpio[18].value = false
gpio[18].function = .output

debugPrint(gpio[18])

var cancelled = false
DispatchQueue.global(qos: .background).async {
    repeat {
        usleep(100)
        gpio[18].value.toggle()
    } while !cancelled
}

// Run.
print("Running, press ENTER to stop")
let _ = readLine()
cancelled = true

// Shutdown
gpio[18].value = false
gpio[18].function = .input

print("Bye!")
