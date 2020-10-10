//
//  main.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation
import proxy_nio

let server: Socks5Server = Socks5Server()
// server.start(config: .default)
server.start(config: SocksServerConfiguration(auth: .pass(username: "admin", password: "password1"), port: 1080))
// curl -x socks5://admin:password@localhost:1080 baidu.com
