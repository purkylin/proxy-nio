//
//  SocksRequest.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

// Document: https://tools.ietf.org/html/rfc1928

import Foundation
import NIO

enum SocksRequest {
    case initial(req: RequestInitial)
    case command(req: RequestCommand)
    case auth(username: String, password: String)
    case relay(bytes: [UInt8])
}

/**
+----+----------+----------+
|VER | NMETHODS | METHODS  |
+----+----------+----------+
| 1  |    1     | 1 to 255 |
+----+----------+----------+
 */
struct RequestInitial {
    let version: UInt8
    let methods: [Socks.AuthType]
    
    init?(from buffer: inout ByteBuffer) throws {
        guard let version = buffer.readInteger(as: UInt8.self) else { return nil }
        guard version == Socks.version else { throw SocksError.invalidVersion }
        
        guard let count = buffer.readInteger(as: UInt8.self), let methodBytes = buffer.readBytes(length: Int(count)) else { return nil }
        
        self.version = version
        self.methods = methodBytes.compactMap { Socks.AuthType.init(rawValue: $0) }
    }
}

/**
 +----+----------+----------+
 |VER | NMETHODS | METHODS  |
 +----+----------+----------+
 | 1  |    1     | 1 to 255 |
 +----+----------+----------+
 */

struct RequestAuth {
    let version: UInt8
    let username: String
    let password: String
    
    init?(from buffer: inout ByteBuffer) throws {
        guard let version = buffer.readInteger(as: UInt8.self) else { return nil }
        guard version == Socks.version else { throw SocksError.invalidVersion }
        self.version = version
        
        self.username = ""
        self.password = ""
    }
}

/**
+----+-----+-------+------+----------+----------+
|VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
+----+-----+-------+------+----------+----------+
| 1  |  1  | X'00' |  1   | Variable |    2     |
+----+-----+-------+------+----------+----------+
 */
struct RequestCommand {
    let version: UInt8
    let cmd: Socks.RequestType
    let addr: SocksAddress
    let port: UInt16
    
    init?(from buffer: inout ByteBuffer) throws {
        guard let version = buffer.readInteger(as: UInt8.self) else { return nil }
        self.version = version
        
        guard let cmdValue = buffer.readInteger(as: UInt8.self) else { return nil }
        guard let cmd = Socks.RequestType(rawValue: cmdValue) else {
            throw SocksError.invalidRequest
        }
        self.cmd = cmd
        
        guard buffer.skipBytes(1) else { return nil }
        
        guard let addr = try SocksAddress(from: &buffer) else { return nil }
        self.addr = addr
        guard let port = buffer.readInteger(as: UInt16.self) else { return nil }
        self.port = port
    }
}

struct SocksAddress {
    let atyp: Socks.Atyp
    let bytes: [UInt8]
    
    init?(from buffer: inout ByteBuffer) throws {
        guard let num = buffer.readInteger(as: UInt8.self) else { return nil }
        guard let type = Socks.Atyp(rawValue: num) else { throw SocksError.invalidRequest }
        
        self.atyp = type
        
        switch atyp {
        case .v4:
            guard let bytes = buffer.readBytes(length: 4) else { return nil }
            self.bytes = bytes
        case .v6:
            guard let bytes = buffer.readBytes(length: 14) else { return nil }
            self.bytes = bytes
        case .domain:
            guard let len = buffer.readInteger(as: UInt8.self) else { return nil }
            guard let bytes = buffer.readBytes(length: Int(len)) else { return nil }
            self.bytes = bytes
        }
    }
    
    private init(atyp: Socks.Atyp, bytes: [UInt8]) {
        self.atyp = atyp
        self.bytes = bytes
    }
    
    var host: String? {
        switch atyp {
        case .v4:
            let value = bytes[0..<4].withUnsafeBytes { $0.load(as: UInt32.self) }
            let addr = in_addr(s_addr: value)

            var buffer = [Int8](repeating: 0, count: Int(INET_ADDRSTRLEN))
            
            _ = withUnsafePointer(to: addr) { pointer in
                inet_ntop(AF_INET, pointer, &buffer, UInt32(INET_ADDRSTRLEN))
            }
            return String(cString: buffer)
        case .v6:
            return "v6"
        case .domain:
            return String(bytes: bytes, encoding: .utf8)
        }
    }
    
    static func zero(for type: Socks.Atyp) -> Self {
        switch type {
        case .v4:
            return SocksAddress(atyp: .v4, bytes: Array<UInt8>(repeating: 0, count: 4))
        case .v6:
            return SocksAddress(atyp: .v4, bytes: Array<UInt8>(repeating: 0, count: 16))
        case .domain:
            fatalError("Shouldn't call this function")
        }
    }
}
