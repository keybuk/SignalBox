//
//  main.swift
//  TestPWM
//
//  Created by Scott James Remnant on 5/27/20.
//

import Foundation
import RaspberryPi

// Set GPIO12 to output from PWM1.
let gpio = try! GPIO()
gpio[12].value = false
gpio[12].function = .alternateFunction0

// Set up the PWM FIFO.
let pwm = try! PWM()
pwm[1].isEnabled = false
pwm[1].useFifo = false

// Set PWM1 to use Data and 8-bit Serializer mode.
pwm[1].mode = .serializer
pwm[1].range = 8
pwm[1].data = 0b11001010_11111111_11111111_11111111

// Stop the PWM clock.
let clock = try! Clock()
clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

// Set the PWM clock to 0.1ms ticks.
clock[.pwm].source = .oscillator
clock[.pwm].mash = 0
clock[.pwm].divisor = ClockDivisor(integer: 1_920, fractional: 0)

// Enable the PWM
pwm[1].isEnabled = true

// Start the Clock.
clock[.pwm].isEnabled = true
while !clock[.pwm].isRunning {}

debugPrint(gpio[12])
debugPrint(pwm[1])
debugPrint(clock[.pwm])

// Run.
print("Running, press ENTER to stop")
let _ = readLine()

// Shutdown.
pwm[1].isEnabled = false

clock[.pwm].isEnabled = false
while clock[.pwm].isRunning {}

gpio[12].value = false
gpio[12].function = .input

print("Bye!")
