//
//  SocksDecoder.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

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
    
    var state: State = .waiting
    
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
            var peekBuffer = buffer
            guard let request = try RequestAuth(from: &peekBuffer) else { return .needMoreData }
            let output = self.wrapInboundOut(SocksRequest.auth(req: request))
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
    
    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        // This method is needed, otherwise will infinite loop
        assert(state == .waiting)
        return .needMoreData
    }
    
    func decoderAdded(context: ChannelHandlerContext) {
        logger.debug("has added decoder")
        state = .initial
    }
    
    func decoderRemoved(context: ChannelHandlerContext) {
        logger.debug("has remove decoder")
    }
}
