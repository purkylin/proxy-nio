//
//  main.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation
import proxy_nio
import http
import Dispatch

func testSocks() {
    let server: Socks5Server = Socks5Server()
    server.start(config: .default)
}

func testSocksWithAuth() {
    // curl -x socks5://admin:password@localhost:1080 baidu.com
    let server: Socks5Server = Socks5Server()
    server.start(config: SocksConfiguration(auth: .pass(username: "admin", password: "password"), port: 1080))
}

func testShadowsocks() {
    let server: ShadowsocksServer = ShadowsocksServer()
    // Config your shadowsocks server
    let config = ShadowsocksConfiguration(host: "your host", port: 1080, password: "your password")
    server.start(config: config)
}

func testHttp() {
    // curl -x localhost:1080 baidu.com
    let server = HttpServer()
    server.start(port: 1080)
}

testHttp()
