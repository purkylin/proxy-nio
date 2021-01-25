//
//  UDPHandler.swift
//  
//
//  Created by Purkylin King on 2021/1/25.
//

import NIO

class UDPHandler: ChannelInboundHandler {
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
            guard let header = try? UDPHeader(from: &buffer) else { return }
            guard header.frag == 0 else {
                fatalError("not support fragment")
            }
            
            guard let host = header.addr.host, let remote = try? SocketAddress.makeAddressResolvingHost(host, port: Int(header.port)) else {
                fatalError("invalid address")
            }
     
            let outBuffer = context.channel.allocator.buffer(bytes: header.data)
            let outEnvolope = AddressedEnvelope(remoteAddress: remote, data: outBuffer, metadata: nil)
            context.writeAndFlush(self.wrapOutboundOut(outEnvolope), promise: nil)
        } else {
            guard let data = buffer.readBytes(length: buffer.readableBytes) else { return }
            let header = UDPHeader(addr: .zero(for: .v4), port: 0, data: data)
            let outbuffer = context.channel.allocator.buffer(bytes: header.bytes)
            // logger.info(.init(stringLiteral: "out: \(header.bytes)"))
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
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}
