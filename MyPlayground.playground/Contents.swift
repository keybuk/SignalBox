import Cocoa

import DCC

var str = "Hello, playground"

let timing = try! SignalTiming(pulseWidth: 14.5)
let address = MultiFunctionAddress.primary(3)
let instruction1 = Speed128Step(93, direction: .forward)
let instruction2 = DecoderAcknowledgementRequest()


//let instruction: Function0to4 = [ .f1, .f2, .fl ]

//let packet = MultiFunctionPacket(address: address, instruction: instruction)

let packet = MultiFunctionPacket2(address: address, instructions: instruction1, instruction2)


var packer = BitPacker<UInt8>()
packer.add(packet)
print(packer)

var signalPacker = SignalPacker(timing: timing)
signalPacker.add(packet)

print(signalPacker)

// let x = MultiFunctionDecoder(address: .primary(3), speedSteps: 128)
//     .speed(93, direction: .forward)
//     .requestAcknowledgement()
//
// x : MultiFunctionPacket2<Speed128Step, DecoderAcknowledgementRequest>

// let y = MultiFunctionDecoder(address: .extended(153))
//     .speed(14, direction: .forward)
//
// y : MultiFunctionPacket<Speed28Step>, address = .extended(153)

// let z = Broadcast()
//     .emergencyStop()
//
// z : MultiFunctionPacket<EmergencyStop28Step>, address = .broadcast

// let xx = MultiFunctionDecoder(address: .extended(153))
//     .function0to4([ .f1, .f2, .f3 ])

// is this just over-complicating?

