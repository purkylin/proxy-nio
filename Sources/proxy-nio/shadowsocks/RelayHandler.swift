//
//  RelayHandler.swift
//  
//
//  Created by Purkylin King on 2020/10/23.
//

import NIO
import Logging

class RelayHandler {
    private var partner: RelayHandler?

    private var context: ChannelHandlerContext?

    private var pendingRead: Bool = false
    
    var isLocal: Bool = false
    var cryptor: Cryptor?

    private init(cryptor: Cryptor?) {
        self.cryptor = cryptor
    }
}

extension RelayHandler {
    static func matchedPair(cryptor: Cryptor? = nil) -> (RelayHandler, RelayHandler) {
        let first = RelayHandler(cryptor: cryptor)
        let second = RelayHandler(cryptor: cryptor)

        first.partner = second
        second.partner = first

        return (first, second)
    }
}

extension RelayHandler {
    private func partnerWrite(_ data: NIOAny, promise: EventLoopPromise<Void>? = nil) {
        guard let context = self.context else { return }
        
        guard let cryptor = self.cryptor  else {
            context.write(data, promise: nil)
            return
        }
        
        do {
            if isLocal {
                var buffer = self.unwrapInboundIn(data)
                if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                    let ciphertext = try cryptor.decrypt(payload: bytes)
                    
                    var outBuffer = context.channel.allocator.buffer(capacity: ciphertext.count)
                    outBuffer.writeBytes(ciphertext)
                    self.context?.write(self.wrapOutboundOut(outBuffer), promise: nil)
                    self.context?.flush()
                }
            } else {
                var buffer = self.unwrapInboundIn(data)
                if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                    let ciphertext = try cryptor.encrypt(payload: bytes)
                    
                    var outBuffer = context.channel.allocator.buffer(capacity: ciphertext.count)
                    outBuffer.writeBytes(ciphertext)
                    self.context?.write(self.wrapOutboundOut(outBuffer), promise: nil)
     
                }
            }
        } catch {
            partnerCloseFull()
        }
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

extension RelayHandler: ChannelDuplexHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

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
//        print("error: \(error.localizedDescription)")
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
