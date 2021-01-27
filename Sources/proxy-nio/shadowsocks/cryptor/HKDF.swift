//
//  File.swift
//  
//
//  Created by Purkylin King on 2020/10/15.
//

import Foundation
import Crypto

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

func evpBytesToKey(password:String, keyLen:Int) -> [UInt8] {
    var m = [Data]()
    guard let passwd = password.data(using: String.Encoding.utf8) else {
        return []
    }

    while m.reduce(0, {$0 + $1.count}) < keyLen {
        let data = m.count > 0 ? m.last! + passwd : passwd
        m.append(data.md5())
    }
    let final = m.reduce(Data(), +)
    return Array(final.bytes[0...(keyLen - 1)])
}
