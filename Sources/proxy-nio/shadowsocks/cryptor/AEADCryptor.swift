//
//  AEADCryptor.swift
//  
//
//  Created by Purkylin King on 2020/10/15.
//

import Foundation
import Crypto
import struct NIO.ByteBuffer

public class AEADCryptor: Cryptor {
    private let password: String
    private let keyLen: Int
    private let saltLen: Int
    
    private lazy var encryptor: AEADCryptor.Encryptor = {
        let salt = Data.random(length: saltLen)
        return Encryptor(password: password, salt: salt, keyLen: keyLen)
    }()
    
    private var decryptor: AEADCryptor.Decryptor?
    
    required init(password: String, keyLen: Int = 32, saltLen: Int = 32) {
        self.password = password
        self.keyLen = keyLen
        self.saltLen = saltLen
    }
    
    func encrypt(payload: [UInt8]) throws -> [UInt8] {
        try encryptor.encrypt(bytes: payload)
    }
    
    func decrypt(payload: [UInt8]) throws -> [UInt8] {
        let ciphertext: [UInt8]
        
        if decryptor == nil {
            guard payload.count >= saltLen else {
                logger.warning("The salt length is not enough")
                return []
            }
            
            let salt = payload[0..<saltLen]
            
            self.decryptor = Decryptor(password: password, salt: Data(salt), keyLen: keyLen)
            ciphertext = Array(payload[saltLen...])
        } else {
            ciphertext = payload
        }
        
        return try self.decryptor!.decrypt(bytes: ciphertext)
    }
}

extension AEADCryptor {
    private class Encryptor {
        private let key: SymmetricKey
        private let salt: Data
        private var nonce = Nonce()
        private let keyLen: Int
        private var hasSendSalt: Bool = false
        
        init(password: String, salt: Data, keyLen: Int) {
            self.salt = salt
            self.keyLen = keyLen
            
            let derivedKey = evpBytesToKey(password: password, keyLen: keyLen)
            let subkey = hkdf_sha1(Data(derivedKey), salt: salt, info: ssInfo, outputSize: keyLen)!
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
            
            logger.debug("encrypt chunk once")
            
            return output
        }
    }
    
    private class Decryptor {
        private let key: SymmetricKey
        private let salt: Data?
        private var nonce = Nonce()
        private let keyLen: Int
        
        private var buffer = ByteBuffer(bytes: [])
        
        init(password: String, salt: Data, keyLen: Int) {
            self.salt = salt
            self.keyLen = keyLen
            
            let derivedKey = evpBytesToKey(password: password, keyLen: keyLen)
            let subkey = hkdf_sha1(Data(derivedKey), salt: salt, info: ssInfo, outputSize: keyLen)!
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
                let length: UInt16 = lengthData.toInteger()!
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
                
                logger.debug("decrypt success once")
            }
            
            return output
        }
        
        private func decrypt(bytes: [UInt8], tag: [UInt8]) throws -> [UInt8] {
            let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce.bytes), ciphertext: bytes, tag: tag)
            return try AES.GCM.open(sealedBox, using: key).bytes
        }
    }
}
