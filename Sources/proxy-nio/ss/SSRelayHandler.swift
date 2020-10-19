//
//  SSRelayHandler.swift
//  
//
//  Created by Purkylin King on 2020/10/15.
//

import Foundation
import NIO

class SSRelayHandler {
    private var partner: SSRelayHandler?

    private var context: ChannelHandlerContext?

    private var pendingRead: Bool = false
    
    var pendingBytes: [UInt8] = []
    
    var isLocal: Bool = false
    var cryptor: Cryptor

    private init(cryptor: Cryptor) {
        self.cryptor = cryptor
    }
}

extension SSRelayHandler {
    static func matchedPair(cryptor: Cryptor) -> (SSRelayHandler, SSRelayHandler) {
        let first = SSRelayHandler(cryptor: cryptor)
        let second = SSRelayHandler(cryptor: cryptor)

        first.partner = second
        second.partner = first

        return (first, second)
    }
}

extension SSRelayHandler {
    private func partnerWrite(_ data: NIOAny) {
        guard let context = self.context else { return }
        do {
            if isLocal {
                let promise = context.eventLoop.makePromise(of: Void.self)
                promise.
                var buffer = self.unwrapInboundIn(data)
                if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                    let ciphertext = try cryptor.decrypt(payload: bytes)
                    print("decrypt success once")
                    
                    var outBuffer = context.channel.allocator.buffer(capacity: ciphertext.count)
                    outBuffer.writeBytes(ciphertext)
                    self.context?.write(self.wrapOutboundOut(outBuffer), promise: nil)
                    self.context?.flush()
                }
            } else {
                var buffer = self.unwrapInboundIn(data)
                if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                    print("write to remote: \(bytes.count), \(bytes)")

                    let ciphertext = try cryptor.encrypt(payload: bytes)
                    
                    var outBuffer = context.channel.allocator.buffer(capacity: ciphertext.count)
                    outBuffer.writeBytes(ciphertext)
                    self.context?.write(self.wrapOutboundOut(outBuffer), promise: nil)
     
                }
            }
        } catch {
            print("crypto failed")
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


extension SSRelayHandler: ChannelDuplexHandler {
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
        print("local: \(context.channel.remoteAddress) has read message")
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
        print("error: \(error.localizedDescription)")
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
