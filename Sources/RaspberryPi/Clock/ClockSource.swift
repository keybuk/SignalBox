//
//  ClockSource.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 6/10/18.
//

/// Clock sources.
public enum ClockSource : UInt32 {
    
    case none       = 0
    case oscillator = 1
    case testDebug0 = 2
    case testDebug1 = 3
    case plla       = 4
    case pllc       = 5
    case plld       = 6
    case hdmiAux    = 7
    
    /// Clock's known frequency (in MHz).
    public var frequency: Float {
        switch self {
        case .oscillator: return 19.2
        // Note: .pllc is ommitted since its value is not stable.
        case .plld: return 500
        case .hdmiAux: return 216
        default: return 0
        }
    }
    
}
