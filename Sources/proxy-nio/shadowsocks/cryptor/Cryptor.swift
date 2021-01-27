//
//  Cryptor.swift
//  
//
//  Created by Purkylin King on 2021/1/27.
//

import Foundation

// ss max tcp chunk size
let maxChunkSize = 0x3FFF

// ss derived key info
let ssInfo = "ss-subkey".data(using: .utf8)!

protocol Cryptor {
    init(password: String, keyLen: Int, saltLen: Int)
    
    func encrypt(payload: [UInt8]) throws -> [UInt8]
    func decrypt(payload: [UInt8]) throws -> [UInt8]
}
