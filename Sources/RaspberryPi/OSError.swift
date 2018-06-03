//
//  OSError.swift
//  RaspberryPi
//
//  Created by Scott James Remnant on 5/31/18.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Errors that can be thrown by system calls.
public enum OSError : Error {
    
    /// Operation was not permitted.
    case operationNotPermitted
    
    /// No such file or directory.
    case noSuchFileOrDirectory
    
    /// Permission was denied accessing a resource.
    case permissionDenied
    
    /// System call failed.
    case systemCallFailed(errno: Int32)
    
    public init(errno: Int32) {
        switch errno {
        case EPERM:
            self = .operationNotPermitted
        case ENOENT:
            self = .noSuchFileOrDirectory
        case EACCES:
            self = .permissionDenied
        default:
            self = .systemCallFailed(errno: errno)
        }
    }
    
}
