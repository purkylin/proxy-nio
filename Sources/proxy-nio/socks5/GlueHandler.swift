//
//  GlueHandler.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/30.
//

import NIO

final class GlueHandler {
    private var partner: GlueHandler?

    private var context: ChannelHandlerContext?

    private var pendingRead: Bool = false
    
    var pendingBytes: [UInt8] = []

    private init() { }
}

extension GlueHandler {
    static func matchedPair() -> (GlueHandler, GlueHandler) {
        let first = GlueHandler()
        let second = GlueHandler()

        first.partner = second
        second.partner = first

        return (first, second)
    }
}

extension GlueHandler {
    func channelActive(context: ChannelHandlerContext) {
        if pendingBytes.count > 0 {
            let buffer = context.channel.allocator.buffer(bytes: pendingBytes)
            context.write(NIOAny(buffer), promise: nil)
        }
    }
    
    private func partnerWrite(_ data: NIOAny) {
        self.context?.write(data, promise: nil)
    }

    private func partnerFlush() {
        self.context?.flush()
    }

    private func partnerWriteEOF() {
        self.context?.close(mode: .output, promise: nil)
    }

    private func partnerCloseFull() {
        self.context?.close(promise: nil)
    }

    private func partnerBecameWritable() {
        if self.pendingRead {
            self.pendingRead = false
            self.context?.read()
        }
    }

    private var partnerWritable: Bool {
        return self.context?.channel.isWritable ?? false
    }
}


extension GlueHandler: ChannelDuplexHandler {
    typealias InboundIn = NIOAny
    typealias OutboundIn = NIOAny
    typealias OutboundOut = NIOAny

    func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.context = nil
        self.partner = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.partner?.partnerWrite(data)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        self.partner?.partnerFlush()
    }

    func channelInactive(context: ChannelHandlerContext) {
        self.partner?.partnerCloseFull()
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let event = event as? ChannelEvent, case .inputClosed = event {
            // We have read EOF.
            self.partner?.partnerWriteEOF()
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.partner?.partnerCloseFull()
    }

    func channelWritabilityChanged(context: ChannelHandlerContext) {
        if context.channel.isWritable {
            self.partner?.partnerBecameWritable()
        }
    }

    func read(context: ChannelHandlerContext) {
        if let partner = self.partner, partner.partnerWritable {
            context.read()
        } else {
            self.pendingRead = true
        }
    }
}
