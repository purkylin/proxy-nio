//
//  SocksResponse.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation

enum SocksResponse {
    case initial(method: Socks.AuthType)
    case auth(success: Bool)
    case command(type: Socks.ResponseType, addr: SocksAddress, port: UInt16)
}
