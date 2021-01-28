//
//  main.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation
import proxy_nio

func testSocks() {
    let server: Socks5Server = Socks5Server()
    server.start(config: .default)
}

func testSocksWithAuth() {
    // curl -x socks5://admin:password@localhost:1080 baidu.com
    let server: Socks5Server = Socks5Server()
    server.start(config: SocksConfiguration(auth: .pass(username: "admin", password: "password1"), port: 1080))
}

func testShadowsocks() {
    let server: ShadowsocksServer = ShadowsocksServer()
    // Config your shadowsocks server
    let config = ShadowsocksConfiguration(host: "your host", port: 1080, password: "your password")
    server.start(config: config)
}

testShadowsocks()
