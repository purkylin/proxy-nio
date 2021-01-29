//
//  HttpServer.swift
//  
//
//  Created by Purkylin King on 2020/10/10.
//

import NIO
import Logging
import NIOHTTP1
import Dispatch

public final class HttpServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    public private(set) var isRunning: Bool = false
    
    public init() { }
    
    public func start(port: Int = 1080) {
        let logger = Logger(label: "http_server")
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes))).flatMap {
                    channel.pipeline.addHandler(HTTPResponseEncoder()).flatMap {
                        channel.pipeline.addHandler(ConnectHandler(logger: Logger(label: "com.apple.nio-connect-proxy.ConnectHandler")))
                    }
                }
            }

        do {
            let channel = try bootstrap.bind(host: "::0", port: port).wait()
            logger.info("start http server on port \(port) success")
            isRunning = true
            try channel.closeFuture.wait()
        } catch {
            logger.error("start http server on port \(port) failed")
        }
    }
    
    public func stop() {
        try? group.syncShutdownGracefully()
    }
}

