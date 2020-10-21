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
    case command(rep: SocksResponseType, addr: SocksAddress)
}

extension SocksResponse {
    func toBytes() -> [UInt8] {
        switch self {
        case .initial(let method):
            return [socksVersion, method.rawValue]
        case .auth(let success):
            return [0x01, success ? 0 : 1]
        case let .command(rep, addr):
            let atyp: SocksCmdAtyp
            switch addr {
            case .v4:
                atyp = .ipv4
            case .v6:
                atyp = .ipv6
            case .domain:
                atyp = .domain
            }
            return [0x5, rep.rawValue, 0x0, atyp.rawValue] + addr.bytes
        }
    }
}
