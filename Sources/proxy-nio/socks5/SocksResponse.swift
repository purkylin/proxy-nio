//
//  File.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation

enum SocksResponse {
    case initial(method: SocksAuthType)
    case auth(success: Bool)
    case command(rep: SocksResponseType, atyp: SocksCmdAtyp, addr: SocksAddress)
}

extension SocksResponse {
    func toBytes() -> [UInt8] {
        switch self {
        case .initial(let method):
            return [socksVersion, method.rawValue]
        case .auth(let success):
            return [0x01, success ? 0 : 1]
        case let .command(rep, atyp, addr):
            return [0x5, rep.rawValue, 0x0, atyp.rawValue] + addr.bytes
        }
    }
}
