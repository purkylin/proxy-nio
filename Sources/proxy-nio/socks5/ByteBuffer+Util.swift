//
//  ByteBuffer+Util.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import NIO

extension ByteBuffer {
    @discardableResult
    mutating func skipBytes(_ len: Int) -> Bool {
        if self.readableBytes >= len {
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
