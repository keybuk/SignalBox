//
//  main.swift
//  TestGPIO
//
//  Created by Scott James Remnant on 5/27/20.
//

import Foundation
import Dispatch
import RaspberryPi

// Set GPIO12 to output.
let gpio = try! GPIO()
gpio[12].value = false
gpio[12].function = .output

debugPrint(gpio[12])

var cancelled = false
DispatchQueue.global(qos: .background).async {
    repeat {
        usleep(500)
        gpio[12].value.toggle()
    } while !cancelled
}

// Run.
print("Running, press ENTER to stop")
let _ = readLine()
cancelled = true

// Shutdown
gpio[12].value = false
gpio[12].function = .input

print("Bye!")
