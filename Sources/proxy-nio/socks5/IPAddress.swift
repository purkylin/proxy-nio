//
//  IPAddress.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/28.
//

import Foundation

enum IPAddress: CustomStringConvertible {
    enum ProtocolFamily {
        case v4
        case v6
    }
    
    struct IPv4Address {
        fileprivate let storage: [UInt8]
        
        init(bytes: [UInt8]) {
            self.storage = bytes
        }
        
        init?(string: String) {
            guard let bytes = Self.fromIPv4(string: string) else { return nil }
            self.storage = bytes
        }
        
        static var zero: Self {
            return Self(bytes: Array.init(repeating: 0x0, count: 4))
        }
        
        fileprivate func toIPv4() -> String {
            let num = storage.withUnsafeBytes { $0.load(as: UInt32.self) }
            let addr = in_addr(s_addr: num)
            var buffer = [Int8](repeating: 0, count: Int(INET_ADDRSTRLEN))
            _ = withUnsafePointer(to: addr) { pointer in
                inet_ntop(AF_INET, pointer, &buffer, UInt32(INET_ADDRSTRLEN))
            }
            
            return String(cString: buffer)
        }
        
        private static func fromIPv4(string: String) -> [UInt8]? {
            var addr = in_addr()
            
            let ret = string.withCString { pointer in
                inet_pton(AF_INET, pointer, &addr)
            }
            
            guard ret == 1 else { return nil }
            
            let num = addr.s_addr
            let array = withUnsafeBytes(of: num, Array.init)

            return array
        }
    }
    
    struct IPv6Address {
        fileprivate let storage: [UInt8]
        
        init(bytes: [UInt8]) {
            self.storage = bytes
        }
        
        init?(string: String) {
            guard let bytes = Self.fromIPv6(string: string) else { return nil }
            self.storage = bytes
        }
        
        static var zero: Self {
            return Self(bytes: Array.init(repeating: 0x0, count: 16))
        }
        
        fileprivate func toIPv6() -> String {
            var addr = sockaddr_in6()
            addr.sin6_family = sa_family_t(AF_INET6)
            
            var buffer = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            
            _ = withUnsafePointer(to: storage) { pointer in
                inet_ntop(AF_INET6, pointer, &buffer, UInt32(INET6_ADDRSTRLEN))
            }
            
            return String(cString: buffer)
        }
        
        private static func fromIPv6(string: String) -> [UInt8]? {
            var addr = in6_addr()
            
            let ret = string.withCString { pointer in
                inet_pton(AF_INET6, pointer, &addr)
            }
            
            guard ret == 1 else { return nil }
            
            return withUnsafeBytes(of: &addr, Array.init)
        }
    }
    
    case v4(IPv4Address)
    case v6(IPv6Address)
    
    var `protocol`: ProtocolFamily {
        switch self {
        case .v4:
            return .v4
        case .v6:
            return .v6
        }
    }
    
    var description: String {
        switch self {
        case .v4(let address):
            return address.toIPv4()
        case .v6(let address):
            return address.toIPv6()
        }
    }
    
    var bytes: [UInt8] {
        switch self {
        case .v4(let address):
            return address.storage
        case .v6(let address):
            return address.storage
        }
    }
}
