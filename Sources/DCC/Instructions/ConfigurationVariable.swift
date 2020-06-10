//
//  ConfigurationVariable.swift
//  DCC
//
//  Created by Scott James Remnant on 5/27/18.
//

public enum ConfigurationVariable : Int {
    
    case primaryAddress = 1
    case vStart
    case accelerationRate
    case decelerationRate
    case vHigh
    case vMid
    case manufacturerVersionNumber
    case manufacturerId
    case totalPWMPeriod
    case emfFeedbackControl = 10
    case packetTimeoutValue
    case powerSourceConversion
    case alternateModeFunction1to8
    case alternateModeFunction9to12
    case decoderLock1
    case decoderLock2
    case extendedAddress1
    case extendedAddress2
    case consistAddress
    // 20 reserved by NMRA for future use.
    case consistAddressActiveForFunction1to8 = 21
    case consistAddressActiveForFunction9to12
    case accelerationAdjustment
    case decelerationAdjustment
    case speedTableMidRangeCabSpeedStep
    // 26 reserved by NMRA for future use.
    case automaticStoppingConfiguration
    case biDirectionalCommsConfiguration
    case configurationData
    case errorInformation = 30
    case indexHigh
    case indexLow
    // 33-46 Output location and functions.
    // 47-64 reserved for manufacturer use.
    case kickStart = 65
    case forwardTrim
    // 67-94 Speed table.
    case reverseTrim = 95
    // 96-104 reserved by NMRA for future use.
    case userIdentifier1 = 105
    case userIdentifier2
    case expandedManfuacturerIdHigh
    case expandedManfuacturerIdLow
    case expandedManufacturerVersionNumberHigh
    case expandedManufacturerVersionNumberMid
    case expandedManufacturerVersionNumberLow
    // 112-256 reserved for manufacturer use.
    // 257-512 indexed area.
    // 513-879 reserved by NMRA for future use.
    // 880-891 reserved by NMRA for future use.
    case decoderLoad = 892
    case dynamicFlags
    case fuelCoal
    case water
    // 896-104 SUSI sound and function modules.
}
