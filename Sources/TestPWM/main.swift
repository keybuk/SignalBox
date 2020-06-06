//
//  main.swift
//  TestPWM
//
//  Created by Scott James Remnant on 5/27/20.
//

import Foundation
import RaspberryPi

// Shutdown PWM1, clear FIFO.
let pwm = try! PWM()
pwm[1].isEnabled = false
pwm[1].useFifo = false

// Stop the PWM clock.
let clock = try! Clock()
clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

// Set PWM1 to use Data and 8-bit Serializer mode.
pwm[1].mode = .serializer
pwm[1].range = 8
pwm[1].data = 0b11001010_11111111_11111111_11111111

// Set the PWM clock to 0.1ms bits.
clock[.pwm].source = .oscillator
clock[.pwm].mash = 0
clock[.pwm].divisor = ClockDivisor(integer: 1_920 / 8, fractional: 0)

// Set GPIO18 to output from PWM1.
let gpio = try! GPIO()
gpio[18].value = false
gpio[18].function = .alternateFunction5

// Start the Clock.
clock[.pwm].isEnabled = true
while !clock[.pwm].isRunning {}

// Enable the PWM
pwm[1].isEnabled = true

debugPrint(gpio[18])
debugPrint(pwm[1])
debugPrint(clock[.pwm])

// Run.
print("Running, press ENTER to stop")
let _ = readLine()

// Shutdown.
gpio[18].value = false
gpio[18].function = .input

pwm[1].isEnabled = false

clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

print("Bye!")
