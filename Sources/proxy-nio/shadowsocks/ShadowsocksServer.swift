//
//  ShadowsocksServer.swift
//  
//
//  Created by Purkylin King on 2021/1/26.
//

import NIO

public struct ShadowsocksConfiguration {
    public enum Method {
        case aes_128_gcm
        case aes_192_gcm
        case aes_256_gcm
        
        var keyLen: Int {
            switch self {
            case .aes_128_gcm:
                return 16
            case .aes_192_gcm:
                return 24
            case .aes_256_gcm:
                return 32
            }
        }
        
        var saltLen: Int {
            switch self {
            case .aes_128_gcm:
                return 16
            case .aes_192_gcm:
                return 24
            case .aes_256_gcm:
                return 32
            }
        }
    }
    
    let localPort: Int

    let host: String
    let port: Int
    let method: Method
    let password: String
    
    public init(host: String, port: Int, password: String, method: Method = .aes_256_gcm, localPort: Int = 1080) {
        self.host = host
        self.port = port
        self.password = password
        self.method = method
        self.localPort = localPort
    }
}

public final class ShadowsocksServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    public private(set) var isRunning: Bool = false
    
    public init() { }
    
    public func start(config: ShadowsocksConfiguration) {
        if isRunning {
            logger.warning("shadowsocks server has started")
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
                    channel.pipeline.configShadowsocks(config: config)
                 }
             }
             // Enable SO_REUSEADDR for the accepted Channels
             .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
             .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
             .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        do {
            let channel = try bootstrap.bind(host: "::0", port: config.localPort).wait()
            logger.debug("start ss server on port \(config.port) success")
            isRunning = true
            
            try channel.closeFuture.wait()
        } catch {
            logger.error("start ss server on port \(config.port) failed")
        }
        
        logger.debug("ss server has stopped")
        isRunning = false
    }
    
    public func stop() {
        try? group.syncShutdownGracefully()
    }
}

extension ChannelPipeline {
    func configShadowsocks(config: ShadowsocksConfiguration) -> EventLoopFuture<Void> {
        let encoderHandler = MessageToByteHandler(SocksEncoder())
        let decoder = SocksDecoder()
        let decoderHandler = ByteToMessageHandler(decoder)
        let handler = ShadowsocksHandler(config: config, decoder: decoder)
        
        return self.addHandlers(encoderHandler, decoderHandler, handler)
    }
}
