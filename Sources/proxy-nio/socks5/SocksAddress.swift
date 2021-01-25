//
//  File.swift
//  
//
//  Created by Purkylin King on 2021/1/25.
//

import NIO

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
