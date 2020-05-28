//
//  main.swift
//  
//
//  Created by Scott James Remnant on 5/28/20.
//

import Foundation
import RaspberryPi

let gpio = try GPIO()
debugPrint(gpio[12])
debugPrint(gpio[17])
debugPrint(gpio[18])
debugPrint(gpio[19])

let clock = try Clock()
debugPrint(clock[.pwm])

let pwm = try PWM()
debugPrint(pwm[1])

let dma = try DMA()
debugPrint(dma[5])
