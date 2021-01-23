//
//  SocksHandler.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

class SocksHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = SocksRequest
    typealias OutboundOut = SocksResponse
    
    private let decoder = SocksDecoder()

    private let serverPort: Int
    private let auth: SocksServerConfiguration.Auth
    
    init(config: SocksServerConfiguration) {
        self.serverPort = config.port
        self.auth = config.auth
    }
    
    func channelActive(context: ChannelHandlerContext) {
        let handler = ByteToMessageHandler(decoder)
    
        // context.pipeline.addHandlers([handler, MessageToByteHandler(SocksEncoder())], position: .before(self)).cascade(to: nil)
        context.pipeline.addHandler(handler, name: "decoder")
            .and(context.pipeline.addHandler(MessageToByteHandler(SocksEncoder()), name: "encoder"))
            .cascade(to: nil)
    }
    
    func getAuthMethod(supportMethods: [Socks.AuthType]) -> Socks.AuthType {
        guard needAuth else {
            return .none
        }
        
        if supportMethods.contains(.password) {
            return .password
        } else {
            return .unsupported
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        switch req {
        case .initial(let request):
            logger.info("receive initial")
            let authMethod = getAuthMethod(supportMethods: request.methods)
            let response = SocksResponse.initial(method: authMethod)
            context.write(self.wrapOutboundOut(response)).cascade(to: nil)
            
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
        case .command(let request):
            logger.info("receive command")
            switch request.cmd {
            case .connect:
                connectTo(host: request.addr.host!, port: request.port, context: context)
            case .bind:
                let response = SocksResponse.command(type: .unsupported, addr: SocksAddress.zero(for: .v4), port: 0)
                context.write(self.wrapOutboundOut(response)).cascade(to: nil)
            case .udp:
                break
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
        future.flatmp
        future.whenComplete { result in
            switch result {
            case .success(let channel):
                let response = SocksResponse.command(type: .success, addr: .zero(for: .v4), port: 0)
                context.writeAndFlush(self.wrapOutboundOut(response)).whenComplete { result in
                    print(result)
                    context.channel.relay(peerChannel: channel).and(context.pipeline.removeHandler(self)).cascade(to: nil)
                }
            case .failure(let error):
                print(error.localizedDescription)
                let response = SocksResponse.command(type: .unreachable, addr: .zero(for: .v4), port: 0)
                context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
                context.close(mode: .output, promise: nil)
            }
        }
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        logger.info("remove socks handler")

        let promise = context.eventLoop.makePromise(of: Void.self)
        context.pipeline.removeHandler(name: "decoder", promise: promise)
        context.pipeline.removeHandler(name: "encoder", promise: promise)
        promise.futureResult.always { result in
            let ctx = context
            print("dd")
        }
//        context.pipeline.removeHandler(name: "decoder").and(context.pipeline.removeHandler(name: "encoder")).whenComplete { result in
//            let ctx = context
//            print("dd")
//        }
    }
    
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
}


extension MessageToByteHandler: RemovableChannelHandler { }
