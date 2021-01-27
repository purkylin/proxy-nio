//
//  main.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation
import proxy_nio
//import Crypto
//import NIO

//DispatchQueue.global().async {
//    let udp = UDPServer()
//    udp.start()
//}

//let udp = UDPServer()
//udp.start()
//print("finish")

// let server: Socks5Server = Socks5Server()
// server.start(config: .default)
//server.start(config: SocksServerConfiguration(auth: .pass(username: "admin", password: "password1"), port: 1080))
// curl -x socks5://admin:password@localhost:1080 baidu.com

let server: ShadowsocksServer = ShadowsocksServer()
server.start(config: .default)

func pton4(host: String, port: Int) -> sockaddr_in? {
    var ipv4Addr = in_addr()
    let ret = host.withCString { pointer in
        inet_pton(AF_INET, pointer, &ipv4Addr)
    }
    
    guard ret == 1 else { return nil }
    
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(port).bigEndian
    addr.sin_addr.s_addr = ipv4Addr.s_addr
    
    return addr
}


