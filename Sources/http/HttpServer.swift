//
//  HttpServer.swift
//  
//
//  Created by Purkylin King on 2020/10/10.
//

import NIO

public final class HttpServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    public private(set) var isRunning: Bool = false
    
    public init() { }
    
    public func start(config: SocksServerConfiguration = .default) {
        if isRunning {
            logger.warning("socks server has started")
            return
        }
        
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
             .serverChannelOption(ChannelOptions.backlog, value: 256)
             .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

             // Set the handlers that are appled to the accepted Channels
             .childChannelInitializer { channel in
                 // Ensure we don't read faster than we can write by adding the BackPressureHandler into the pipeline.
                 channel.pipeline.addHandler(BackPressureHandler()).flatMap { v in
                    channel.pipeline.addHandler(SocksHandler(config: config))
                 }
             }

             // Enable SO_REUSEADDR for the accepted Channels
             .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
             .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
             .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        do {
            let channel = try bootstrap.bind(host: "::1", port: config.port).wait()
            logger.debug("start socks server on port \(config.port) success")
            isRunning = true
            
            try channel.closeFuture.wait()
        } catch {
            logger.error("start socks server on port \(config.port) failed")
        }
        
        logger.debug("socks server has stopped")
        isRunning = false
    }
    
    public func stop() {
        try? group.syncShutdownGracefully()
    }
}

