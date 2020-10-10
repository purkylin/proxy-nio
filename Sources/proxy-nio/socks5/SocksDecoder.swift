//
//  SocksDecoder.swift
//  Socks5Server
//
//  Created by Purkylin King on 2020/9/25.
//

import Foundation
import NIO

class SocksCmdDecoder: ByteToMessageDecoder {
    typealias InboundOut = SocksRequest
    
    private var cmd: SocksCmdType = .connect
    private var atyp: SocksCmdAtyp = .ipv4
    
    /**
    +----+-----+-------+------+----------+----------+
    |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
    +----+-----+-------+------+----------+----------+
    | 1  |  1  | X'00' |  1   | Variable |    2     |
    +----+-----+-------+------+----------+----------+
     */
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var peekBuffer = buffer
        
        guard let ver = peekBuffer.readInteger(as: UInt8.self), let cmdValue = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard ver == socksVersion else {
            throw SocksError.invalidVersion
        }
        
        guard let cmd = SocksCmdType(rawValue: cmdValue) else { throw SocksError.invalidCommand }
        guard peekBuffer.skipBytes(1) else { return .needMoreData }
        guard let atypValue = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard let atyp = SocksCmdAtyp(rawValue: atypValue) else {
            throw SocksError.invalidATYP
        }
        
        guard let addr = peekBuffer.readAddress(atyp: atyp) else { return .needMoreData }
        
        buffer = peekBuffer
        
        let request = SocksRequest.command(cmd: cmd, atyp: atyp, addr: addr)
        let output = self.wrapInboundOut(request)
        context.fireChannelRead(output)
        
        return .continue
    }
}

/**
+----+----------+----------+
|VER | NMETHODS | METHODS  |
+----+----------+----------+
| 1  |    1     | 1 to 255 |
+----+----------+----------+
 */
class SocksInitialDecoder: ByteToMessageDecoder, RemovableChannelHandler {
    typealias InboundOut = SocksRequest
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var peekBuffer = buffer
        
        guard let ver = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard ver == socksVersion else { throw SocksError.invalidVersion }
        
        guard let count = peekBuffer.readInteger(as: UInt8.self), let typeBytes = peekBuffer.readBytes(length: Int(count)) else { return .needMoreData }
        let types = typeBytes.compactMap { SocksAuthType.init(rawValue: $0) }
        
        buffer = peekBuffer
        
        let request = SocksRequest.initial(authTypes: types)
        let output = self.wrapInboundOut(request)
        context.fireChannelRead(output)
        
        return .continue
    }
}

/**
+----+-----+------------+------+----------+
|VER | LEN |  USERNAME  | LEN  | PASSWORD |
+----+-----+------------+------+----------+
| 1  |  1  | Variable   |  1   | Variable |
+----+-----+------------+------+----------+
 */
class SocksAuthDecoder: ByteToMessageDecoder {
    typealias InboundOut = SocksRequest
    
    var username: String = ""
    var password: String = ""
    
    enum State {
        case version
        case username
        case password
    }
    
    private var state: State = .version
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var peekBuffer = buffer

        guard buffer.readableBytes >= 1 else { return .needMoreData }

        guard let ver = peekBuffer.readInteger(as: UInt8.self) else { return .needMoreData }
        guard ver == 0x1 else { throw SocksError.invalidVersion }
        
        guard let username = peekBuffer.readString(), let password = peekBuffer.readString() else { return .needMoreData }
        
        buffer = peekBuffer

        let request = SocksRequest.auth(username: username, password: password)
        let output = self.wrapInboundOut(request)
        context.fireChannelRead(output)
        
        return .continue
    }
}
