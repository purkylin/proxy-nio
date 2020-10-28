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
    
    func peekInteger<T: FixedWidthInteger>(as: T.Type = T.self) -> T? {
        let size = MemoryLayout<T>.size
        guard self.readableBytes >= size else { return nil }
        return getInteger(at: self.readerIndex, endianness: .big, as: `as`)
    }
    
    mutating func readAddress(atyp: Socks.Atyp) -> SocksAddress? {
        switch atyp {
        case .v4:
            let requiredLength = 6
            guard self.readableBytes >= requiredLength else { return nil }
            guard let bytes = readBytes(length: requiredLength) else { return nil }
            return SocksV4Address(bytes: bytes)
        case .v6:
            let requiredLength = 18
            guard self.readableBytes >= requiredLength else { return nil }
            guard let bytes = readBytes(length: requiredLength) else { return nil }
            return SocksV6Address(bytes: bytes)
        case .domain:
            guard let len = self.peekInteger(as: UInt8.self) else { return nil }
            let count = Int(len)
            guard let bytes = self.readBytes(length: count + 3) else { return nil }
            return SocksDomainAddress(bytes: bytes)
        }
    }
    
    /// Read a fix length string, first byte represent length
    mutating func readString() -> String? {
        guard self.readableBytes >= 1 else { return nil }
   
        guard let peekLen = self.getInteger(at: self.readerIndex, as: UInt8.self) else { return nil }
        guard self.readableBytes >= 1 + peekLen else { return nil }
        self.skipBytes(1)
        return self.readString(length: Int(peekLen))
    }
    
    /// Read all available bytes
    mutating func readAll() -> [UInt8] {
        guard self.readableBytes > 0 else { return [] }
        return self.readBytes(length: self.readableBytes) ?? []
    }
}
