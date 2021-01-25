//
//  SocksAddress.swift
//  
//
//  Created by Purkylin King on 2021/1/25.
//

import NIO

struct SocksAddress {
    let atyp: Socks.Atyp
    private let storage: [UInt8]
    
    var bytes: [UInt8] {
        return [atyp.rawValue] + storage
    }
    
    init?(from buffer: inout ByteBuffer) throws {
        guard let num = buffer.readInteger(as: UInt8.self) else { return nil }
        guard let type = Socks.Atyp(rawValue: num) else { throw SocksError.invalidRequest }
        
        self.atyp = type
        
        switch atyp {
        case .v4:
            guard let bytes = buffer.readBytes(length: 4) else { return nil }
            self.storage = bytes
        case .v6:
            guard let bytes = buffer.readBytes(length: 14) else { return nil }
            self.storage = bytes
        case .domain:
            guard let len = buffer.readInteger(as: UInt8.self) else { return nil }
            guard let bytes = buffer.readBytes(length: Int(len)) else { return nil }
            self.storage = bytes
        }
    }
    
    private init(atyp: Socks.Atyp, bytes: [UInt8]) {
        self.atyp = atyp
        self.storage = bytes
    }
    
    var host: String? {
        switch atyp {
        case .v4:
            let value = storage[0..<4].withUnsafeBytes { $0.load(as: UInt32.self) }
            let addr = in_addr(s_addr: value)

            var buffer = [Int8](repeating: 0, count: Int(INET_ADDRSTRLEN))
            _ = withUnsafePointer(to: addr) { pointer in
                inet_ntop(AF_INET, pointer, &buffer, UInt32(INET_ADDRSTRLEN))
            }
            
            return String(cString: buffer)
        case .v6:
            var addr = sockaddr_in6()
            addr.sin6_family = sa_family_t(AF_INET6)
            
            var buffer = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            withUnsafeMutableBytes(of: &addr.sin6_addr) { $0.copyBytes(from: storage[..<16]) }
            inet_ntop(AF_INET6, &addr.sin6_addr, &buffer, UInt32(INET6_ADDRSTRLEN))
            
            return String(cString: buffer)
        case .domain:
            return String(bytes: storage, encoding: .utf8)
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
