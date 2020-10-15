//
//  Data+Byte.swift
//  
//
//  Created by Purkylin King on 2020/10/15.
//

import Foundation

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
