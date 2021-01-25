//
//  SocksEncoder.swift
//  
//
//  Created by Purkylin King on 2021/1/23.
//

import NIO

class SocksEncoder: MessageToByteEncoder, RemovableChannelHandler {
    typealias OutboundIn = SocksResponse
    
    func encode(data: SocksResponse, out: inout ByteBuffer) throws {
        logger.info("out: \(data.toBytes())")
        out.writeBytes(data.toBytes())
    }
}

extension SocksResponse {
    func toBytes() -> [UInt8] {
        switch self {
        case .initial(let method):
            return [Socks.version, method.rawValue]
        case .auth(let success):
            return [0x01, success ? 0 : 1]
        case let .command(type, addr, port):
            return [Socks.version, type.rawValue, 0x0] + addr.bytes + port.bytes
        }
    }
}

extension MessageToByteHandler: RemovableChannelHandler { }
