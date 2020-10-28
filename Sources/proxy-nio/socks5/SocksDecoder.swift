//
//  SocksDecoder.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

class SocksInitialDecoder: ByteToMessageDecoder, RemovableChannelHandler {
    typealias InboundOut = SocksRequest
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        /**
        +----+----------+----------+
        |VER | NMETHODS | METHODS  |
        +----+----------+----------+
        | 1  |    1     | 1 to 255 |
        +----+----------+----------+
         */
        
        var peekBuffer = buffer
        
        guard let ver = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard ver == Socks.version else { throw SocksError.invalidVersion }
        
        guard let count = peekBuffer.readInteger(as: UInt8.self), let typeBytes = peekBuffer.readBytes(length: Int(count)) else { return .needMoreData }
        let types = typeBytes.compactMap { Socks.AuthType.init(rawValue: $0) }
        
        buffer = peekBuffer
        
        let request = SocksRequest.initial(authTypes: types)
        let output = self.wrapInboundOut(request)
        context.fireChannelRead(output)
        
        return .continue
    }
}

class SocksCmdDecoder: ByteToMessageDecoder {
    typealias InboundOut = SocksRequest
    
    private var cmd: Socks.RequestType = .connect
    private var atyp: Socks.Atyp = .v4
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        /**
        +----+-----+-------+------+----------+----------+
        |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
        +----+-----+-------+------+----------+----------+
        | 1  |  1  | X'00' |  1   | Variable |    2     |
        +----+-----+-------+------+----------+----------+
         */
        
        var peekBuffer = buffer
        
        guard let ver = peekBuffer.readInteger(as: UInt8.self), let cmdValue = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard ver == Socks.version else {
            throw SocksError.invalidVersion
        }
        
        guard let cmd = Socks.RequestType(rawValue: cmdValue) else { throw SocksError.invalidRequest }
        
        guard peekBuffer.skipBytes(1) else { return .needMoreData }
        
        guard let atypValue = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard let atyp = Socks.Atyp(rawValue: atypValue) else {
            throw SocksError.invalidRequest
        }
        
        guard let addr = peekBuffer.readAddress(atyp: atyp) else { return .needMoreData }
        
        buffer = peekBuffer
        
        let request = SocksRequest.command(cmd: cmd, addr: addr)
        let output = self.wrapInboundOut(request)
        context.fireChannelRead(output)
        
        return .continue
    }
}

class SocksAuthDecoder: ByteToMessageDecoder {
    typealias InboundOut = SocksRequest
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        /**
        +----+-----+------------+------+----------+
        |VER | LEN |  USERNAME  | LEN  | PASSWORD |
        +----+-----+------------+------+----------+
        | 1  |  1  | Variable   |  1   | Variable |
        +----+-----+------------+------+----------+
         */
        
        var peekBuffer = buffer

        guard buffer.readableBytes >= 1 else { return .needMoreData }

        guard let ver = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard ver == 0x1 else { throw SocksError.invalidRequest }
        
        guard let username = peekBuffer.readString(), let password = peekBuffer.readString() else { return .needMoreData }
        
        buffer = peekBuffer

        let request = SocksRequest.auth(username: username, password: password)
        let output = self.wrapInboundOut(request)
        context.fireChannelRead(output)
        
        return .continue
    }
}
