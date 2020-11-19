//
//  SocksAddress.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/28.
//

import Foundation

protocol SocksAddress {
    var host: String { get }
    var port: Int { get }
    
    var atyp: Socks.Atyp { get }
    var bytes: [UInt8] { get }
}

struct SocksV4Address: SocksAddress {
    var host: String
    var port: Int
    
    let atyp: Socks.Atyp = .v4
    
    private let storage: [UInt8]
    
    init?(host: String, port: Int) {
        var v4Addr = in_addr()

        let ret = host.withCString { pointer in
            inet_pton(AF_INET, pointer, &v4Addr)
        }

        guard ret == 1 else { return nil }

        self.storage = withUnsafeBytes(of: v4Addr.s_addr, Array.init) + UInt16(port).bytes
        self.host = host
        self.port = port
    }
    
    init?(bytes: [UInt8]) {
        guard bytes.count == 6 else { return nil }
        
        let value = bytes[0..<4].withUnsafeBytes { $0.load(as: UInt32.self) }
        let addr = in_addr(s_addr: value)
        
        var buffer = [Int8](repeating: 0, count: Int(INET_ADDRSTRLEN))
        
        _ = withUnsafePointer(to: addr) { pointer in
            inet_ntop(AF_INET, pointer, &buffer, UInt32(INET_ADDRSTRLEN))
        }

        host = String(cString: buffer)
        let port16: UInt16 = bytes[4...].toInteger()!
        port = Int(port16)
        self.storage = bytes
    }
    
    var bytes: [UInt8] {
        return storage
    }
    
    static func localAddress(on port: Int) -> SocksV4Address {
        return SocksV4Address(host: "0.0.0.0", port: port)!
    }
}

extension SocksV4Address: CustomStringConvertible {
    var description: String {
        return "\(host):\(port)"
    }
}

struct SocksDomainAddress: SocksAddress {
    var host: String
    var port: Int
    
    let atyp: Socks.Atyp = .domain
    private let storage: [UInt8]
    
    init?(host: String, port: Int) {
        let count = UInt8(host.utf8.count)
        self.host = host
        self.port = port
        self.storage = [] + count.bytes + host.data(using: .utf8)!.bytes + port.bigEndian.bytes
    }
    
    init?(bytes: [UInt8]) {
        guard bytes.count > 1 else {
            return nil
        }
        
        guard let count = bytes.first, bytes.count == count + 3 else { return nil }
        
        let cnt = Int(count)
        let mid = 1 + cnt
        
        let hostBytes = bytes[1..<mid]
        let portBytes = bytes[mid...]
        
        self.host = String(data: Data(hostBytes), encoding: .utf8)!
        let port = portBytes.toInteger(as: UInt16.self)!
        self.port = Int(port)
        self.storage = bytes
    }
    
    var bytes: [UInt8] {
        return storage
    }
}

struct SocksV6Address: SocksAddress {
    var host: String
    var port: Int
    
    let atyp: Socks.Atyp = .v6
    
    private let storage: [UInt8]
    
    init?(host: String, port: Int) {
        var addr = in6_addr()

        let ret = host.withCString { pointer in
            inet_pton(AF_INET6, pointer, &addr)
        }

        guard ret == 1 else { return nil }

        self.host = host
        self.port = port
        self.storage = withUnsafeBytes(of: &addr, Array.init) + UInt16(port).bytes
    }
    
    init?(bytes: [UInt8]) {
        guard bytes.count == 18 else {
            return nil
        }
        
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)

        var buffer = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))

        withUnsafeMutableBytes(of: &addr.sin6_addr) { $0.copyBytes(from: bytes[0...16]) }
        
        inet_ntop(AF_INET6, &addr.sin6_addr, &buffer, UInt32(INET6_ADDRSTRLEN))

        self.host = String(cString: buffer)
        let port16: UInt16 = bytes[16...].toInteger()!
        self.port = Int(port16)
        self.storage = bytes
    }
    
    var bytes: [UInt8] {
        return storage
    }
}

extension SocksV6Address: CustomStringConvertible {
    var description: String {
        return "\(host):\(port)"
    }
}
