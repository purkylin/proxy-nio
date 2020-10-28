//
//  SocksHandler.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

class SocksHandler: ChannelInboundHandler {
    typealias InboundIn = SocksRequest
    typealias OutboundOut = SocksResponse
    
    let serverPort: Int
    let auth: SocksServerConfiguration.Auth
    
    init(config: SocksServerConfiguration) {
        self.serverPort = config.port
        self.auth = config.auth
    }
            
    private let encoder = MessageToByteHandler(SocksEncoder())
    
    private var needAuth: Bool {
        if case .pass = auth {
            return true
        } else {
            return false
        }
    }
    
    private func checkAuth(username: String, password: String) -> Bool {
        if case let .pass(rightUsername, rightPassword) = auth {
            if username == rightUsername && password == rightPassword {
                return true
            }
        }
        return false
    }
    
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
    
    func handleInitialRequest(context: ChannelHandlerContext, authTypes: [Socks.AuthType]) {
        logger.debug("receive initial socks request")
        
        let responseMethod: Socks.AuthType
        
        if needAuth {
            if authTypes.contains(.password) {
                responseMethod = .password
            } else {
                responseMethod = .unsupported
            }
        } else {
            if authTypes.contains(.none) {
                responseMethod = .none
            } else {
                responseMethod = .unsupported
            }
        }
        
        switch responseMethod {
        case .none:
            replaceDecoderHandler(context: context, newHandler: ByteToMessageHandler(SocksCmdDecoder()))
        case .password:
            replaceDecoderHandler(context: context, newHandler: ByteToMessageHandler(SocksAuthDecoder()))
        case .unsupported:
            break
        default:
            fatalError()
        }
        
        let output = SocksResponse.initial(method: responseMethod)
        context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        
        switch request {
        case .initial(let authTypes):
            handleInitialRequest(context: context, authTypes: authTypes)
        case .command(let cmd, let addr):
            logger.debug("receive cmd socks request")
            if cmd == .connect {
                logger.info("request host: \(addr)")
                context.pipeline.remove(handlerType: ByteToMessageHandler<SocksInitialDecoder>.self, promise: nil)
                connectTo(host: addr.host, port: addr.port, context: context)
            } else if cmd == .udp {
                logger.info("receive udp cmd request")
                
        
                createUDP(context: context).flatMap { channel -> EventLoopFuture<Void> in
                    let addr = SocksV4Address.localAddress(on: channel.localAddress!.port!)
                    let output = SocksResponse.command(rep: .success, addr: addr)
                    return context.writeAndFlush(self.wrapOutboundOut(output))
                }.whenComplete { _ in
                    context.pipeline.removeHandler(self.encoder)
                }
            } else {
                logger.error("unsupported command: \(cmd.rawValue)")
                let addr = SocksV4Address.localAddress(on: 0)
                let output = SocksResponse.command(rep: .unsupported, addr: addr)
                context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
            }
        case .auth(let username, let password):
            logger.debug("receive auth socks request")
            let success = checkAuth(username: username, password: password)
            
            let output = SocksResponse.auth(success: success)
            context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
            
            if success {
                replaceDecoderHandler(context: context, newHandler: ByteToMessageHandler(SocksCmdDecoder()))
            } else {
                logger.error("wrong username/password, \(username):\(password)")
                context.channel.close(mode: .output, promise: nil)
            }
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error(.init(stringLiteral: error.localizedDescription))
        context.channel.close(mode: .all, promise: nil)
    }
    
    func connectTo(host: String, port: Int, context: ChannelHandlerContext) {
        logger.debug("connecting to \(host):\(port)")
        let channelFuture = ClientBootstrap(group: context.eventLoop).connect(host: host, port: port)
        
        channelFuture.whenSuccess { channel in
            self.connectSuccessed(channel: channel, context: context)
        }
        
        channelFuture.whenFailure { error in
            self.connectFailed(error: error, context: context)
        }
    }
    
    func createUDP(context: ChannelHandlerContext) -> EventLoopFuture<Channel> {
        let bootstrap = DatagramBootstrap(group: context.eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.recvAllocator, value: FixedSizeRecvByteBufferAllocator(capacity: 30 * 2048))
            .channelInitializer { channel in
                channel.pipeline.addHandler(UDPRelayHandler())
        }

        let channelFuture = try! bootstrap.bind(host: "0.0.0.0", port: 0)
        return channelFuture
    }
    
    func connectTo2(host: String, port: Int, context: ChannelHandlerContext) {
        logger.debug("connecting to \(host):\(port)")
        let bootstrap = DatagramBootstrap(group: context.eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        
        let channelFuture = bootstrap.bind(host: host, port: port)
        channelFuture.whenSuccess { channel in
            self.glue(peerChannel: channel, context: context)
        }
    }
    
    func connectSuccessed(channel: Channel, context: ChannelHandlerContext) {
//        logger.info("connected to \(channel.remoteAddress!)")
//        let output = SocksResponse.command(rep: .success, atyp: .ipv4, addr: SocksAddress.localAddress)
        
//        context.writeAndFlush(self.wrapOutboundOut(output)).flatMap {
//            context.pipeline.removeHandler(self.encoder)
//        }.whenComplete { _ in
//            self.glue(peerChannel: channel, context: context)
//        }
//
        context.pipeline.removeHandler(self.encoder)
        self.glue(peerChannel: channel, context: context)


    }
    
    func connectFailed(error: Error, context: ChannelHandlerContext) {
        logger.error("connected failed: \(error)")

        let output = SocksResponse.command(rep: .unreachable, addr: SocksV4Address.localAddress(on: 0))
        context.writeAndFlush(self.wrapOutboundOut(output), promise: nil)
        context.close(mode: .output, promise: nil)
    }
    
    func glue(peerChannel: Channel, context: ChannelHandlerContext) {
        let (localGue, peerGlue) = GlueHandler.matchedPair()
        let output = SocksResponse.command(rep: .success, addr: SocksV4Address.localAddress(on: 0))
        localGue.pendingBytes = output.toBytes()

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

extension SocksHandler: RemovableChannelHandler { }

extension MessageToByteHandler: RemovableChannelHandler { }

class SocksEncoder: MessageToByteEncoder, RemovableChannelHandler {
    typealias OutboundIn = SocksResponse
    
    func encode(data: SocksResponse, out: inout ByteBuffer) throws {
        logger.debug("out: \(data.toBytes())")
        out.writeBytes(data.toBytes())
    }
}

extension ChannelPipeline {
    public func remove<Handler: RemovableChannelHandler>(handlerType: Handler.Type, promise: EventLoopPromise<Void>?) {
        let future = self.handler(type: handlerType).flatMap { handler -> EventLoopFuture<Void> in
            return self.removeHandler(handler)
        }
        future.cascade(to: nil)
    }
}

//class UDPHandler: ChannelInboundHandler {
//    typealias Inbound = <#type expression#>
//    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        <#code#>
//    }
//}


class UDPRelayHandler: ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    var source: SocketAddress? = nil

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data
        
        if source == nil {
            source = envelope.remoteAddress
        }
        
        let isLocal = source == envelope.remoteAddress
        
        if isLocal {
            guard buffer.readInteger(as: UInt16.self) == 0 else {
                return
            }
            
            let frag = buffer.readInteger(as: UInt8.self)!
            let atypRaw = buffer.readInteger(as: UInt8.self)!
            let atyp = Socks.Atyp(rawValue: atypRaw)!
            
            let addr = buffer.readAddress(atyp: atyp)!
            let data = buffer.readBytes(length: buffer.readableBytes)!
            let targetAddress = try! SocketAddress.makeAddressResolvingHost(addr.host, port: addr.port)
            print(envelope.remoteAddress)
      
            let outBuffer = context.channel.allocator.buffer(bytes: data)
       
            let outEnvolope = AddressedEnvelope(remoteAddress: targetAddress, data: outBuffer, metadata: nil)
            
            context.writeAndFlush(self.wrapOutboundOut(outEnvolope), promise: nil)
        } else {
            let header: [UInt8] = [0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0]
            let data = buffer.readBytes(length: buffer.readableBytes)!
            let outbuffer = context.channel.allocator.buffer(bytes: header + data)
            let envolope = AddressedEnvelope(remoteAddress: source!, data: outbuffer, metadata: nil)
            context.writeAndFlush(self.wrapOutboundOut(envolope), promise: nil)
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.flush()
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }

}
    
