//
//  File.swift
//  
//
//  Created by Purkylin King on 2021/1/27.
//

import Foundation

struct Nonce {
    private let length: Int
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
