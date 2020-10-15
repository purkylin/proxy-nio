//
//  main.swift
//  
//
//  Created by Purkylin King on 2020/10/9.
//

import Foundation
import proxy_nio
import Crypto
import NIO

let server: Socks5Server = Socks5Server()
// server.start(config: .default)
//server.start(config: SocksServerConfiguration(auth: .pass(username: "admin", password: "password1"), port: 1080))
// curl -x socks5://admin:password@localhost:1080 baidu.com

func test() {
    let salt = Data.random(length: 32)
    let encryptor = Cryptor(password: "password", salt: salt)
    let decryptor = Cryptor(password: "password", salt: salt)
    let encrypedData = encryptor.encrypt(payload: Array("hello".utf8))
    let rawData = decryptor.decrypt(payload: encrypedData)!
    
    if let text = String(data: Data(bytes: rawData), encoding: .utf8) {
        print("decrypt success")
    } else {
        print("decrypt failed")
    }
}


test()

extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }
        
        let chars = hex.map { $0 }
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .map { String(chars[$0]) + String(chars[$0 + 1]) }
            .compactMap { UInt8($0, radix: 16) }
        
        guard hex.count / bytes.count == 2 else { return nil }
        self.init(bytes)
    }
    
    var bytes:[UInt8] {
          return [UInt8](self)
    }
    
    func hexString() -> String {
        return self.map { String(format:"%02x", $0) }.joined()
    }
    
    static func random(length: Int) -> Data {
        var data = Data(count: length)
        _ = data.withUnsafeMutableBytes {
          SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }
        return data
    }
}

enum CryptError: Error {
    case failed
}

class Cryptor {
    private let masterKey: String
    private let salt: Data
    private let key: SymmetricKey
    private var iv: UInt64 = 0 // + UInt32 + UInt64
    
    private let info = "ss-sbukey".data(using: .utf8)!
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
    
    private func encrypt(bytes: [UInt8]) -> AES.GCM.SealedBox {
        let result = try AES.GCM.seal(bytes, using: key, nonce: nonce)
        iv += 1
        return result
    }
    
    func encrypt(payload: [UInt8]) -> [UInt8] {
        var output = [UInt8]()
        // max length: 0x3FFF
        let length = UInt16(payload.count)
        let lengthResult = encrypt(bytes: length.bytes)
        output += lengthResult.ciphertext
        output += lengthResult.tag
        
        let payloadResult = encrypt(bytes: payload)
        output += payloadResult.ciphertext
        output += payloadResult.tag
        
        return output
    }
    
    func decrypt(bytes: [UInt8], tag: [UInt8]) throws -> Data {
        defer {
            self.iv += 1
        }
        
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: bytes, tag: tag)
        return try! AES.GCM.open(sealedBox, using: key)
    }
    
    func decrypt(payload: [UInt8]) throws -> [UInt8]? {
        var buffer = ByteBuffer(bytes: payload)
        guard let encryptedLengthData = buffer.readBytes(length: 2) else {
            return nil
        }
        
        guard let lengthTag = buffer.readBytes(length: 16) else { return nil }
        
        let lengthData = decrypt(bytes: encryptedLengthData, tag: lengthTag)
        let length = withUnsafeBytes(of: lengthData) { pointer in
            return pointer.load(as: UInt16.self).bigEndian
        }
        
        guard let encryptedData = buffer.readBytes(length: Int(length)) else { return nil }
        guard let dataTag = buffer.readBytes(length: 16) else { return nil }
        
        let raw = decrypt(bytes: encryptedData, tag: dataTag)
        return raw.map { $0 }
    }
}

extension FixedWidthInteger {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian, Array.init)
    }
}

func hkdf_sha1(_ key: Data, salt: Data, info: Data, outputSize: Int = 20) -> Data? {
    // It would be nice to make this generic over <H: HashFunction> if HashFunction had byteCount instead of each hash
    // individually implementing it.
    let iterations = UInt8(ceil(Double(outputSize) / Double(Insecure.SHA1.byteCount)))
    guard iterations <= 255 else {
        return nil
    }
    
    let prk = HMAC<Insecure.SHA1>.authenticationCode(for: key, using: SymmetricKey(data: salt))
    let key = SymmetricKey(data: prk)
    var hkdf = Data()
    var value = Data()
    
    for i in 1...iterations {
        value.append(info)
        value.append(i)
        
        let code = HMAC<Insecure.SHA1>.authenticationCode(for: value, using: key)
        hkdf.append(contentsOf: code)
        
        value = Data(code)
    }

    return hkdf.prefix(outputSize)
}
