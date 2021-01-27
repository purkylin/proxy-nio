//
//  Socks5Server.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import NIO
import Logging

public struct SocksConfiguration {
    public enum Auth {
        case none
        case pass(username: String, password: String)
    }
    
    var auth: Auth
    var port: Int
    
    public init(auth: Auth, port: Int) {
        self.auth = auth
        self.port = port
    }
    
    public static let `default` = SocksConfiguration(auth: .none, port: 1080)
}

public final class Socks5Server {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    public private(set) var isRunning: Bool = false
    
    public init() { }
    
    public func start(config: SocksConfiguration = .default) {
        if isRunning {
            logger.warning("socks5 server has started")
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
                    channel.pipeline.configSocks(config: config)
                 }
             }
             // Enable SO_REUSEADDR for the accepted Channels
             .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
             .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
             .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        do {
            let channel = try bootstrap.bind(host: "::0", port: config.port).wait()
            logger.debug("start socks server on port \(config.port) success")
            isRunning = true
            
            try channel.closeFuture.wait()
        } catch {
            logger.error("start socks server on port \(config.port) failed")
        }
        
        logger.debug("socks5 server has stopped")
        isRunning = false
    }
    
    public func stop() {
        try? group.syncShutdownGracefully()
    }
}

extension ChannelPipeline {
    func configSocks(config: SocksConfiguration) -> EventLoopFuture<Void> {
        let encoderHandler = MessageToByteHandler(SocksEncoder())
        let decoder = SocksDecoder()
        let decoderHandler = ByteToMessageHandler(decoder)
        let handler = SocksHandler(config: config, decoder: decoder) {
            self.removeHandler(encoderHandler).and(self.removeHandler(decoderHandler)).cascade(to: nil)
        }
        
        return self.addHandlers(encoderHandler, decoderHandler, handler)
    }
}
