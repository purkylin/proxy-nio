//
//  ByteBuffer+Util.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

extension ByteBuffer {
    @discardableResult
    mutating func skipBytes(_ len: Int) -> Bool {
        if self.readableBytes > 0 {
            self.moveReaderIndex(forwardBy: len)
            return true
        } else {
            return false
        }
    }
    
    mutating func readAddress(atyp: SocksCmdAtyp) -> SocksAddress? {
        switch atyp {
        case .ipv4:
            guard let packed = self.readBytes(length: 4), let port = self.readInteger(as: UInt16.self) else { return nil }
            let addr = IPAddress.v4(IPAddress.IPv4Address.init(bytes: packed))
            return .v4(addr: addr, port: Int(port))
        case .ipv6:
            guard let packed = self.readBytes(length: 16),
                   let port = self.readInteger(as: UInt16.self) else {
                 return nil
             }
            let addr = IPAddress.v6(IPAddress.IPv6Address.init(bytes: packed))
            return .v6(addr: addr, port: Int(port))

        case .domain:
            guard let len = self.readInteger(as: UInt8.self), let addr = self.readString(length: Int(len)), let port = self.readInteger(as: UInt16.self) else { return nil }
            return .domain(addr: addr, port: Int(port))
        }
    }
    
    // First byte represent length
    mutating func readString() -> String? {
        guard self.readableBytes >= 1 else { return nil }
   
        guard let peekLen = self.getInteger(at: self.readerIndex, as: UInt8.self) else { return nil }
        guard self.readableBytes >= 1 + peekLen else { return nil }
        self.skipBytes(1)
        return self.readString(length: Int(peekLen))
    }
}
