//
//  SocksRequest.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import NIO

enum SocksRequest {
    case initial(req: RequestInitial)
    case command(req: RequestCommand)
    case auth(req: RequestAuth)
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
 +----+------+----------+------+----------+
 |VER | ULEN |  UNAME   | PLEN |  PASSWD  |
 +----+------+----------+------+----------+
 | 1  |  1   | 1 to 255 |  1   | 1 to 255 |
 +----+------+----------+------+----------+
 */

struct RequestAuth {
    let version: UInt8
    let username: String
    let password: String
    
    init?(from buffer: inout ByteBuffer) throws {
        guard let version = buffer.readInteger(as: UInt8.self) else { return nil }
        guard version == 0x1 else { throw SocksError.invalidRequest }
        self.version = version
        
        guard let username = buffer.readString() else { return nil }
        self.username = username
        
        guard let password = buffer.readString() else { return nil }
        self.password = password
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
