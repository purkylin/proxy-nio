//
//  Cryptor.swift
//  
//
//  Created by Purkylin King on 2020/10/15.
//

import Foundation
import Crypto
import struct NIO.ByteBuffer

class Cryptor {
    private let masterKey: String
    private let salt: Data
    private let key: SymmetricKey
    private var iv: UInt64 = 0 // + UInt32 + UInt64
    
    private let info = "ss-subkey".data(using: .utf8)!
    private var nonce: AES.GCM.Nonce {
        let bytes = Array(repeating: 0, count: 4) + iv.bytes
        return try! AES.GCM.Nonce(data: bytes)
    }
    
    init(password: String, salt: Data) {
        self.masterKey = password
        let keyLen = 32
        self.salt = salt
        let subkey = hkdf_sha1(masterKey.data(using: .utf8)!, salt: salt, info: info, outputSize: keyLen)!
        self.key = SymmetricKey(data: subkey)
    }
    
    private func encrypt(bytes: [UInt8]) throws -> AES.GCM.SealedBox {
        let result = try AES.GCM.seal(bytes, using: key, nonce: nonce)
        iv += 1
        return result
    }
    
    func encrypt(payload: [UInt8]) throws -> [UInt8] {
        var output = [UInt8]()
        // TODO verify max length: 0x3FFF
        let length = UInt16(payload.count)
        let lengthBox = try encrypt(bytes: length.bytes)
        output += lengthBox.ciphertext
        output += lengthBox.tag
        
        let payloadBox = try encrypt(bytes: payload)
        output += payloadBox.ciphertext
        output += payloadBox.tag
        
        return output
    }
    
    private func decrypt(bytes: [UInt8], tag: [UInt8]) throws -> Data {
        defer {
            self.iv += 1
        }
        
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: bytes, tag: tag)
        return try! AES.GCM.open(sealedBox, using: key)
    }
    
    func decrypt(payload: [UInt8]) throws -> [UInt8]? {
        var buffer = ByteBuffer(bytes: payload)
        guard let encryptedLength = buffer.readBytes(length: 2) else {
            return nil
        }
        
        guard let lengthTag = buffer.readBytes(length: 16) else { return nil }
        
        let lengthData = try decrypt(bytes: encryptedLength, tag: lengthTag)
        let length = withUnsafeBytes(of: lengthData) { pointer in
            return pointer.load(as: UInt16.self).bigEndian
        }
        
        guard let encryptedPayload = buffer.readBytes(length: Int(length)) else { return nil }
        guard let payloadTag = buffer.readBytes(length: 16) else { return nil }
        
        let data = try decrypt(bytes: encryptedPayload, tag: payloadTag)
        return data.bytes
    }
}
