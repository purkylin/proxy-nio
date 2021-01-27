//
//  Socks.swift
//  
//
//  Created by Purkylin King on 2020/10/28.
//

import Foundation
import Logging

let logger: Logger = {
    var obj = Logger(label: "proxy-nio")
    obj.logLevel = .debug
    return obj
}()

struct Socks {
    static let version: UInt8 = 5
    
    enum Atyp: UInt8 {
        case v4 = 1
        case domain = 3
        case v6 = 4
    }
    
    enum AuthType: UInt8 {
        case none        = 0x00
        case gssapi      = 0x01
        case password    = 0x02
        case unsupported = 0xFF
    }

    enum RequestType: UInt8 {
        case connect = 1
        case bind = 2
        case udp = 3
    }
    
    enum ResponseType: UInt8 {
        case success = 0
        case connectFailed
        case ruleNotAllowed
        case badNetwork
        case unreachable
        case connectRejected
        case timeout
        case unsupported
        case unsupportedAddressType
        case undefined
    }
}

enum SocksError: Error {
    case readFailed
    case invalidRequest
    case invalidVersion
}
