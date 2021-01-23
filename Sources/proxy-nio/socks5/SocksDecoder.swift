//
//  SocksDecoder.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

class SocksDecoder: ByteToMessageDecoder {
    typealias InboundOut = SocksRequest
    
    enum State {
        case initial
        case auth
        case cmd
        case udp
        case waiting
    }
    
    var state: State = .initial
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        switch state {
        case .initial:
            var peekBuffer = buffer
            guard let request = try RequestInitial(from: &peekBuffer) else { return .needMoreData }
            let output = self.wrapInboundOut(SocksRequest.initial(req: request))
            buffer = peekBuffer
            state = .waiting
            context.fireChannelRead(output)
        case .auth:
            // TODO
            var peekBuffer = buffer
            guard let request = try RequestInitial(from: &peekBuffer) else { return .needMoreData }
            let output = self.wrapInboundOut(SocksRequest.initial(req: request))
            buffer = peekBuffer
            state = .waiting
            context.fireChannelRead(output)
        case .cmd:
            var peekBuffer = buffer
            guard let request = try RequestCommand(from: &peekBuffer) else { return .needMoreData }
            let output = self.wrapInboundOut(SocksRequest.command(req: request))
            buffer = peekBuffer
            state = .waiting
            context.fireChannelRead(output)
        default:
            break
        }
        
        return .continue
    }
    
    func decoderRemoved(context: ChannelHandlerContext) {
        logger.info("remove decoder")
    }
}
