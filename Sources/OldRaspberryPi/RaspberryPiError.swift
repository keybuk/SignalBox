//
//  RaspberryPiError.swift
//  SignalBox
//
//  Created by Scott James Remnant on 12/31/16.
//
//


/// Errors that can be thrown by the `RaspberryPi` module.
public enum RaspberryPiError: Error {
    
    /// Permission was denied accessing a resource.
    case permissionDenied
    
    /// System call failed.
    case systemCallFailed(errno: Int32)
    
    /// The mailbox request was invalid.
    case invalidMailboxRequest
    
    /// The mailbox response received was invalid.
    case invalidMailboxResponse
    
    /// The mailbox request failed.
    case mailboxRequestFailed

}
