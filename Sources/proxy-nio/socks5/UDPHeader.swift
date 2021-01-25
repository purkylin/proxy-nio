//
//  UDPHeader.swift
//  
//
//  Created by Purkylin King on 2021/1/25.
//

import NIO

/*
 +----+------+------+----------+----------+----------+
 |RSV | FRAG | ATYP | DST.ADDR | DST.PORT |   DATA   |
 +----+------+------+----------+----------+----------+
 | 2  |  1   |  1   | Variable |    2     | Variable |
 +----+------+------+----------+----------+----------+
 */
struct UDPHeader {
    let frag: UInt8
    let addr: SocksAddress
    let port: UInt16
    let data: [UInt8]
    
    init?(from buffer: inout ByteBuffer) throws {
        guard buffer.skipBytes(2) else { return nil }
        guard let frag = buffer.readInteger(as: UInt8.self) else { return nil }
        guard let addr = try SocksAddress(from: &buffer) else { return nil }
        guard let port = buffer.readInteger(as: UInt16.self) else { return nil }
        
        self.frag = frag
        self.addr = addr
        self.port = port
        self.data = buffer.readAll()
    }
    
    init(addr: SocksAddress, port: UInt16, data: [UInt8] = []) {
        self.frag = 0
        self.addr = addr
        self.port = port
        self.data = data
    }
    
    var bytes: [UInt8] {
        return [0x0, 0x0, frag] + addr.bytes + port.bytes + data
    }
}
