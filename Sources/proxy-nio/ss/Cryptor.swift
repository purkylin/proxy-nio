//
//  Cryptor.swift
//  
//
//  Created by Purkylin King on 2020/10/15.
//

import Foundation
import Crypto
import struct NIO.ByteBuffer
import Logging

fileprivate let maxChunkSize = 0x3FFF
fileprivate let info = "ss-subkey".data(using: .utf8)!

private let logger = Logger(label: "crypto")

struct Nonce {
    let length: Int
    private var storage: [UInt8]
    
    // Little endian
    var bytes: [UInt8] {
        return storage
    }
    
    init(length: Int = 12) {
        self.length = length
        self.storage = Array(repeating: 0, count: length)
    }
    
    mutating func increment() {
        for (idx, v) in storage.enumerated() {
            let overflow = v == UInt8.max
            storage[idx] = v &+ 1
            
            if !overflow {
                break
            }
        }
    }
}

class Cryptor {
    var encryptor: Encryptor
    var decryptor: Decryptor?
    var password: String
    
    init(password: String, encryptSalt: Data) {
        self.password = password
        self.encryptor = Encryptor(password: password, salt: encryptSalt)
    }
    
    class Encryptor {
        private let key: SymmetricKey
        private let salt: Data
        private var nonce = Nonce()
        private let keyLen = 32
        private var hasSendSalt: Bool = false
        
        init(password: String, salt: Data) {
            self.salt = salt
            
            let derivedKey = evpBytesToKey(password: password, keyLen: keyLen)
            let subkey = hkdf_sha1(Data(derivedKey), salt: salt, info: info, outputSize: keyLen)!
            self.key = SymmetricKey(data: subkey)
        }
        
        func encrypt(bytes: [UInt8]) throws -> [UInt8] {
            guard bytes.count > 0 else {
                return []
            }
            
            var output = [UInt8]()
            var chunk = ArraySlice(bytes)
            var idx: Int = 0
            
            while true {
                let validLength = min(maxChunkSize, bytes.count - idx)
                chunk = bytes[idx..<validLength+idx]
                idx += validLength
                output += try encrypt(chunk: chunk)
                
                if chunk.count <= maxChunkSize {
                    break
                }
            }
            
            return output
        }
        
        private func encrypt(chunk: ArraySlice<UInt8>) throws -> [UInt8] {
            func combine(box: AES.GCM.SealedBox) -> Data {
                return box.ciphertext + box.tag
            }
            
            let length: UInt16 = UInt16(chunk.count)
            let payload = chunk
            
            var output = [UInt8]()

            let lengthResult = try AES.GCM.seal(length.bytes, using: key, nonce: AES.GCM.Nonce(data: nonce.bytes))
            output += combine(box: lengthResult)
            
            nonce.increment()
            
            let payloadResult = try AES.GCM.seal(payload, using: key, nonce: AES.GCM.Nonce(data: nonce.bytes))
            output += combine(box: payloadResult)
            
            nonce.increment()
            
            assert(output.count == chunk.count + 34)
            
            if !hasSendSalt {
                hasSendSalt = true
                output = salt.bytes + output
            }
            
            logger.info("encrypt chunk once")
            
            return output
        }
    }
    
    class Decryptor {
        private let key: SymmetricKey
        private let salt: Data?
        private var nonce = Nonce()
        private let keyLen = 32
        
        private var buffer = ByteBuffer(bytes: [])
        
        init(password: String, salt: Data) {
            self.salt = salt
            
            let derivedKey = evpBytesToKey(password: password, keyLen: keyLen)
            let subkey = hkdf_sha1(Data(derivedKey), salt: salt, info: info, outputSize: keyLen)!
            self.key = SymmetricKey(data: subkey)
        }
        
        func decrypt(bytes: [UInt8]) throws -> [UInt8] {
            guard bytes.count > 0 else {
                return []
            }
            
            buffer.writeBytes(bytes)

            var output = [UInt8]()
            
            while buffer.readableBytes > 0 {
                let backNonce = nonce
                var peekBuffer = buffer
                
                guard let data1 = peekBuffer.readBytes(length: 2) else {
                    self.nonce = backNonce
                    break
                }
                guard let tag1 = peekBuffer.readBytes(length: 16) else {
                    self.nonce = backNonce
                    break
                }
                
                let lengthData = try decrypt(bytes: data1, tag: tag1)
                let length: UInt16 = lengthData.toInt()!
                nonce.increment()

                guard let data2 = peekBuffer.readBytes(length: Int(length)) else {
                    self.nonce = backNonce
                    break
                }
                
                guard let tag2 = peekBuffer.readBytes(length: 16) else {
                    self.nonce = backNonce
                    break
                }
                output += try decrypt(bytes: data2, tag: tag2)
                nonce.increment()
                buffer = peekBuffer
                
                logger.info("decrypt success once")
            }
            
            return output
        }
        
        private func decrypt(bytes: [UInt8], tag: [UInt8]) throws -> [UInt8] {
            let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce.bytes), ciphertext: bytes, tag: tag)
            return try AES.GCM.open(sealedBox, using: key).bytes
        }
    }

    func encrypt(payload: [UInt8]) throws -> [UInt8] {
        try encryptor.encrypt(bytes: payload)
    }
    
    func decrypt(payload: [UInt8]) throws -> [UInt8] {
        let ciphertext: [UInt8]
        
        if decryptor == nil {
            guard payload.count >= 32 else {
                return []
            }
            
            let salt = payload[0..<32]
            
            self.decryptor = Decryptor(password: password, salt: Data(salt))
            ciphertext = Array(payload[32...])
        } else {
            ciphertext = payload
        }
        
        return try self.decryptor!.decrypt(bytes: ciphertext)
    }
}
