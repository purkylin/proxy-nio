//
//  SocksRequest.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

enum SocksRequest {
    case initial(authTypes: [Socks.AuthType])
    case command(cmd: Socks.RequestType, addr: SocksAddress)
    case auth(username: String, password: String)
}

