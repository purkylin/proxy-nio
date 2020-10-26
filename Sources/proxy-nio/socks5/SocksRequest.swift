//
//  SocksRequest.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

let socksVersion: UInt8 = 5

enum SocksRequest {
    case initial(authTypes: [SocksAuthType])
    case command(cmd: SocksCmdType, atyp: SocksCmdAtyp, addr: SocksAddress)
    case auth(username: String, password: String)
}

enum SocksError: Error {
    case readFailed
    case invalidATYP
    case invalidHost
    case invalidCommand
    case invalidVersion
}

enum SocksCmdAtyp: UInt8 {
    case ipv4 = 1
    case domain = 3
    case ipv6 = 4
}

enum SocksCmdType: UInt8 {
    case connect = 1
    case bind = 2
    case udp = 3
}

enum SocksResponseType: UInt8 {
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

enum SocksAuthType: UInt8 {
    case none          = 0x00
    case gssapi      = 0x01
    case password    = 0x02
    case unsupported = 0xFF
}

enum SocksAddress {
    case v4(addr: IPAddress, port: Int)
    case v6(addr: IPAddress, port: Int)
    case domain(addr: String, port: Int)
    
    static var zeroV4: Self {
        return .v4(addr: IPAddress.v4(IPAddress.IPv4Address.zero), port: 0)
    }
    
    static var zeroV6: Self {
        return .v6(addr: IPAddress.v6(IPAddress.IPv6Address.zero), port: 0)
    }
    
    static var localAddress: Self {
        return .v4(addr: IPAddress.v4(IPAddress.IPv4Address.zero), port: 7777)
    }
    
    static var udpAddress: Self {
        return .v4(addr: IPAddress.v4(IPAddress.IPv4Address.zero), port: 1080)
    }
    
    var bytes: [UInt8] {
        switch self {
        case .v4(let address, let port):
            return address.bytes + UInt16(port).bytes
        case .v6(let address, let port):
            return address.bytes + UInt16(port).bytes
        case .domain(let address, let port):
            let count: UInt8 = UInt8(address.count)
            return count.bytes + address.utf8 + UInt16(port).bytes
        }
    }
    
    var atyp: SocksCmdAtyp {
        switch self {
        case .v4:
            return .ipv4
        case .v6:
            return .ipv6
        case .domain:
            return .domain
        }
    }
    
    var host: String {
        switch self {
        case .v4(let address, _):
            return address.description
        case .v6(let address, _):
            return address.description
        case .domain(let address, _):
            return address
        }
    }
    
    var port: Int {
        switch self {
        case .v4(_, let port):
            return port
        case .v6(_, let port):
            return port
        case .domain(_, let port):
            return port
        }
    }
}
