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
    typealias InboundIn = SocksRequest
    typealias OutboundOut = SocksResponse
    
    private let config: ShadowsocksConfiguration
    private var requestCommand: RequestCommand!

    private unowned let decoder: SocksDecoder
    
    init(config: ShadowsocksConfiguration, decoder: SocksDecoder) {
        self.config = config
        self.decoder = decoder
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        switch req {
        case .initial:
            logger.debug("receive initial")
            let response = SocksResponse.initial(method: .none)
            decoder.state = .cmd
            context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
        case .command(let request):
            logger.debug("receive command")
            
            self.requestCommand = request

            switch request.cmd {
            case .connect:
                connectTo(host: config.host, port: UInt16(config.port), context: context)
            case .bind:
                fatalError("invalid command")
            case .udp:
                // TODO: crypto part
                beginUDP(context: context)
            }
        default:
            break
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error(.init(stringLiteral: error.localizedDescription))
        context.channel.close(mode: .all, promise: nil)
    }
    
    func connectTo(host: String, port: UInt16, context: ChannelHandlerContext)  {
        let future = ClientBootstrap(group: context.eventLoop).connect(host: host, port: Int(port))
       
        future.whenComplete { result in
            switch result {
            case .success(let channel):
                logger.debug("connect host success")
                let response = SocksResponse.command(type: .success, addr: .zero(for: .v4), port: 0)
                context.writeAndFlush(self.wrapOutboundOut(response)).whenComplete { [unowned self] result in
                    context.pipeline.removeHandler(handlerType: MessageToByteHandler<SocksEncoder>.self)
                    context.pipeline.removeHandler(handlerType: ByteToMessageHandler<SocksDecoder>.self)
                    
                    let cryptor = AEADCryptor(password: config.password, keyLen: config.method.keyLen, saltLen: config.method.saltLen)
                    context.channel.relayWithCryptor(peerChannel: channel, cryptor: cryptor).and(context.pipeline.removeHandler(self)).whenComplete { result in
                        let bytes: [UInt8] = requestCommand.addr.bytes + requestCommand.port.bytes
                        let info = try! cryptor.encrypt(payload: bytes)
                        var buffer = channel.allocator.buffer(capacity: info.count)
                        buffer.writeBytes(info)
                        channel.write(NIOAny(buffer), promise: nil)
                        
                    }
                }
            case .failure(let error):
                logger.error("connect host failed, \(error.localizedDescription)")
                let response = SocksResponse.command(type: .unreachable, addr: .zero(for: .v4), port: 0)
                context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
                context.close(mode: .output, promise: nil)
            }
        }
    }
    
    func beginUDP(context: ChannelHandlerContext) {
        // TODO
        let bootstrap = DatagramBootstrap(group: context.eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.recvAllocator, value: FixedSizeRecvByteBufferAllocator(capacity: 30 * 2048))
            .channelInitializer { channel in
                channel.pipeline.addHandler(UDPHandler())
            }
        
        let future = bootstrap.bind(host: "0.0.0.0", port: 0)
        future.whenComplete { result in
            switch result {
            case .success(let channel):
                guard let address = channel.localAddress, let port = address.port else {
                    fatalError("bind udp failed")
                }
                
                logger.debug(.init(stringLiteral: "bind udp on: \(port)"))
                
                let response = SocksResponse.command(type: .success, addr: .zero(for: .v4), port: UInt16(port))
                context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
            case .failure(let error):
                logger.error(.init(stringLiteral: error.localizedDescription))
                let response = SocksResponse.command(type: .connectFailed, addr: .zero(for: .v4), port: 0)
                context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
                context.close(mode: .output, promise: nil)
            }
        }
    }
}

extension ShadowsocksHandler: RemovableChannelHandler { }

extension Channel {
    func relayWithCryptor(peerChannel: Channel, cryptor: Cryptor) -> EventLoopFuture<(Void)> {
        let (localGlue, peerGlue) = SSRelayHandler.matchedPair(cryptor: cryptor)
        localGlue.isLocal = true
        
        return self.pipeline.addHandler(localGlue).and(peerChannel.pipeline.addHandler(peerGlue)).map { _ in
            return
        }
    }
}
