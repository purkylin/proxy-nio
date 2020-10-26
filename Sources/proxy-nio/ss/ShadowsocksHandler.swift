//
//  ShadowsocksHandler.swift
//  
//
//  Created by Purkylin King on 2020/10/15.
//

import Foundation
import NIO
import Logging

class ShadowsocksHandler: ChannelInboundHandler {
    private var logger = Logger(label: "handler")

    typealias InboundIn = SocksRequest
    typealias OutboundOut = SocksResponse
    
    let serverPort: Int
    let auth: SocksServerConfiguration.Auth
    
    var requestHost: SocksAddress!
    
    init(config: SocksServerConfiguration) {
        self.serverPort = config.port
        self.auth = config.auth
        logger.logLevel = .debug
    }
            
    private let encoder = MessageToByteHandler(SocksEncoder())
    
    func channelActive(context: ChannelHandlerContext) {
        let decoder = ByteToMessageHandler(SocksInitialDecoder())
        context.pipeline.addHandler(decoder, name: "decoder", position: .before(self)).and(context.pipeline.addHandler(encoder, name: "encoder", position: .before(self))).cascade(to: nil)
    }
    
    func replaceDecoderHandler(context: ChannelHandlerContext, newHandler: RemovableChannelHandler) {
        let handlerName = "decoder"
        context.pipeline.removeHandler(name: handlerName)
            .and(context.pipeline.addHandler(newHandler, name: handlerName, position: .before(self)))
            .cascade(to: nil)
    }
    
    func handleInitialRequest(context: ChannelHandlerContext, authTypes: [SocksAuthType]) {
        logger.debug("receive initial socks request")
        replaceDecoderHandler(context: context, newHandler: ByteToMessageHandler(SocksCmdDecoder()))
        let output = SocksResponse.initial(method: .none)
        context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        
        switch request {
        case .initial(let authTypes):
            handleInitialRequest(context: context, authTypes: authTypes)
        case .command(let cmd, _, let addr):
            logger.debug("receive cmd socks request")
            if cmd == .connect {
                logger.info("request host: \(addr)")
                context.pipeline.remove(handlerType: ByteToMessageHandler<SocksInitialDecoder>.self, promise: nil)
                self.requestHost = addr
                guard let ip = ProcessInfo.processInfo.environment["SERVER_IP"] else {
                    fatalError("Not found server ip")
                }
                
                guard let portString = ProcessInfo.processInfo.environment["SERVER_PORT"] else {
                    fatalError("Not found server port")
                }
                let port = Int(portString, radix: 10)!
                connectTo(host: ip, port: port, context: context)
            } else if cmd == .udp {
                let output = SocksResponse.command(rep: .unsupported, addr: SocksAddress.zeroV4)
                context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
            } else {
                logger.error("unsupported command: \(cmd.rawValue)")
                let output = SocksResponse.command(rep: .unsupported, addr: SocksAddress.zeroV4)
                context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
            }
        default:
            context.channel.close(mode: .all, promise: nil)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error(.init(stringLiteral: error.localizedDescription))
        context.channel.close(mode: .all, promise: nil)
    }
    
    func connectTo(host: String, port: Int, context: ChannelHandlerContext) {
        let channelFuture = ClientBootstrap(group: context.eventLoop).connect(host: host, port: port)
        
        channelFuture.whenSuccess { channel in
            self.connectSuccessed(channel: channel, context: context)
        }
        
        channelFuture.whenFailure { error in
            self.connectFailed(error: error, context: context)
        }
    }
    
    func connectSuccessed(channel: Channel, context: ChannelHandlerContext) {
        let output = SocksResponse.command(rep: .success, addr: SocksAddress.localAddress)
        
        context.writeAndFlush(self.wrapOutboundOut(output)).flatMap {
            context.pipeline.removeHandler(self.encoder)
        }.whenComplete { _ in
            self.glue(peerChannel: channel, context: context)
        }
    }
    
    func connectFailed(error: Error, context: ChannelHandlerContext) {
        logger.error("connected failed: \(error)")

        let output = SocksResponse.command(rep: .unreachable, addr: SocksAddress.localAddress)
        context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
        context.close(mode: .output, promise: nil)
    }
    
    func glue(peerChannel: Channel, context: ChannelHandlerContext) {
        let salt = Data.random(length: 32)
        let cryptor = Cryptor(password: "mygod", encryptSalt: salt)
        
        let (localGue, peerGlue) = SSRelayHandler.matchedPair(cryptor: cryptor)
        localGue.isLocal = true
        
        
        
        let response = SocksResponse.command(rep: .success, addr: requestHost).toBytes()[3...]
        let info = try! cryptor.encrypt(payload: Array(response))
        let pendingBytes = info
        
        var buffer = peerChannel.allocator.buffer(capacity: pendingBytes.count)
        buffer.writeBytes(pendingBytes)
        peerChannel.write(NIOAny(buffer), promise: nil)

        context.channel.pipeline.addHandler(localGue).and(peerChannel.pipeline.addHandler(peerGlue)).whenComplete { result in
            switch result {
            case .success:
                context.pipeline.remove(handlerType: ByteToMessageHandler<SocksCmdDecoder>.self, promise: nil)
                context.pipeline.removeHandler(self, promise: nil)
            case .failure:
                peerChannel.close(mode: .all, promise: nil)
                context.close(promise: nil)
            }
        }
    }
}

extension ShadowsocksHandler: RemovableChannelHandler { }
