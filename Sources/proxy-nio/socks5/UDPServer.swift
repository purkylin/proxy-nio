//
//  File.swift
//  
//
//  Created by Purkylin King on 2020/10/21.
//

import NIO

public class UDPServer {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    public init() {
        
    }

    public func start() {

        // Using DatagramBootstrap turns out to be the only significant change between TCP and UDP in this case
        let bootstrap = DatagramBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.recvAllocator, value: FixedSizeRecvByteBufferAllocator(capacity: 30 * 2048))
            .channelInitializer { channel in
                channel.pipeline.addHandler(EchoHandler())
        }
        defer {
            try! group.syncShutdownGracefully()
        }

        
        let channel = try! bootstrap.bind(host: "0.0.0.0", port: 1080).wait()

        print("Channel accepting connections on \(channel.localAddress!)")
        try! channel.closeFuture.wait()

        print("Channel closed")

    }
}

private final class EchoHandler: ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        
        let info = self.unwrapInboundIn(data)
        var buffer = info.data
        
//        if let metadata = info.metadata as? SocketAddress {
//            let data = buffer.readBytes(length: buffer.readableBytes)!
//            let header: [UInt8] = [0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0]
//            let outbuffer = context.channel.allocator.buffer(bytes: header + data)
//
//            let envolope = AddressedEnvelope(remoteAddress: metadata, data: outbuffer, metadata: nil)
//            context.writeAndFlush(self.wrapOutboundOut(envolope), promise: nil)
//            return
//        }

        guard buffer.readInteger(as: UInt16.self) == 0 else {
            return
        }
        
        let frag = buffer.readInteger(as: UInt8.self)!
        let atypRaw = buffer.readInteger(as: UInt8.self)!
        let atyp = SocksCmdAtyp(rawValue: atypRaw)!
        
        let addr = buffer.readAddress(atyp: atyp)!
        let data = buffer.readBytes(length: buffer.readableBytes)!
        let targetAddress = try! SocketAddress.makeAddressResolvingHost(addr.host, port: addr.port)
        print(info.remoteAddress)
  
        let outBuffer = context.channel.allocator.buffer(bytes: data)
   
        let envolope = AddressedEnvelope(remoteAddress: targetAddress, data: outBuffer, metadata: nil)
        
        context.writeAndFlush(self.wrapOutboundOut(envolope), promise: nil)
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

/**
 +----+------+------+----------+----------+----------+
 |RSV | FRAG | ATYP | DST.ADDR | DST.PORT |   DATA   |
 +----+------+------+----------+----------+----------+
 | 2  |  1   |  1   | Variable |    2     | Variable |
 +----+------+------+----------+----------+----------+
 */
struct UDPHeader {
    var rsv: UInt16
    var frag: UInt8
    var atyp: UInt8
    var addr: SocksAddress
}



