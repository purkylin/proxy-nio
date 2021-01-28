//
//  SocksHandler.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import NIO

class SocksHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = SocksRequest
    typealias OutboundOut = SocksResponse
    
    private unowned let decoder: SocksDecoder

    private let serverPort: Int
    private let auth: SocksConfiguration.Auth
    
    init(config: SocksConfiguration, decoder: SocksDecoder) {
        self.serverPort = config.port
        self.auth = config.auth
        self.decoder = decoder
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        switch req {
        case .initial(let request):
            logger.debug("receive initial")
            let authMethod = getAuthMethod(supportMethods: request.methods)
            let response = SocksResponse.initial(method: authMethod)
            context.write(self.wrapOutboundOut(response), promise: nil)
            
            switch authMethod {
            case .none:
                decoder.state = .cmd
                context.flush()
            case .password:
                decoder.state = .auth
                context.flush()
            default:
                context.channel.close(mode: .output).cascade(to: nil)
            }
        case .auth(let request):
            logger.debug("receive auth")
            let success = checkAuth(username: request.username, password: request.password)
            let response = SocksResponse.auth(success: success)
            decoder.state = .cmd
            context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
        case .command(let request):
            logger.debug("receive command")
            switch request.cmd {
            case .connect:
                connectTo(host: request.addr.host!, port: request.port, context: context)
            case .bind:
                // Current bind command is not supported
                let response = SocksResponse.command(type: .unsupported, addr: SocksAddress.zero(for: .v4), port: 0)
                context.write(self.wrapOutboundOut(response), promise: nil)
            case .udp:
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
                    context.channel.relay(peerChannel: channel).and(context.pipeline.removeHandler(self)).cascade(to: nil)
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
    
    func handlerRemoved(context: ChannelHandlerContext) {
        logger.debug("remove socks handler")
    }
    
    private func getAuthMethod(supportMethods: [Socks.AuthType]) -> Socks.AuthType {
        guard needAuth else {
            return .none
        }
        
        if supportMethods.contains(.password) {
            return .password
        } else {
            return .unsupported
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
    
    private var needAuth: Bool {
        if case .pass = auth {
            return true
        } else {
            return false
        }
    }
}

extension ChannelPipeline {
    func removeHandler<T: RemovableChannelHandler>(handlerType: T.Type) {
        self.context(handlerType: handlerType).whenSuccess {
            self.removeHandler(context: $0).whenFailure { error in
                fatalError(error.localizedDescription)
            }
        }
    }
}


