//
//  File.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation

enum SocksResponse {
    case initial(method: Socks.AuthType)
    case auth(success: Bool)
    case command(rep: Socks.ResponseType, addr: SocksAddress)
}

extension SocksResponse {
    func toBytes() -> [UInt8] {
        switch self {
        case .initial(let method):
            return [Socks.version, method.rawValue]
        case .auth(let success):
            return [0x01, success ? 0 : 1]
        case let .command(rep, addr):
            let atyp = addr.atyp
            return [Socks.version, rep.rawValue, 0x0, atyp.rawValue] + addr.bytes
        }
    }
}
