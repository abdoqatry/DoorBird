//
//  SodiumEncryption.swift
//  DoorBird
//
//  Created by Admin on 12/04/2023.
//

import Foundation
//import Sodium

    public enum EncryptionType {
        case none
        case chacha20_poly1305
    }


    
    
@objcMembers
class SodiumEncryption: NSObject {

    public struct Constants {
        public static let nonceLengthChacha20Poly1305 = 8
        public static let nonceLengthChacha20Poly1305Ieft = 12
    }
    

    static func decrypt(cypher: UnsafePointer<UInt8>, cypherLen: NSInteger, nonce: UnsafePointer<UInt8>, password: UnsafePointer<UInt8>) -> Data? {
        var output: Data
        let outLen = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        var result: Int32 = -1

        output = Data(count: cypherLen - Int(crypto_aead_chacha20poly1305_ABYTES))
        result = output.withUnsafeMutableBytes { (outputPtr: UnsafeMutablePointer<UInt8>!) in
            return crypto_aead_chacha20poly1305_decrypt(outputPtr, outLen, nil, cypher, UInt64(cypherLen), nil, 0, nonce, password)
        }
        
        print(output)
        print(result)

        if result == 0 {
            return output
        }
        return nil
    }

    static func encrypt(plain: UnsafePointer<UInt8>, plainLen: NSInteger, nonce: UnsafePointer<UInt8>, password: UnsafePointer<UInt8>) -> Data? {
        var output: Data
        let outLen = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        var result: Int32 = -1

        output = Data(count: plainLen + Int(crypto_aead_chacha20poly1305_ABYTES))
        result = output.withUnsafeMutableBytes { (outputPtr: UnsafeMutablePointer<UInt8>!) in
            return crypto_aead_chacha20poly1305_encrypt(outputPtr, outLen, plain, UInt64(plainLen), nil, 0, nil, nonce, password)
        }

        if result == 0 {
            return output
        }
        return nil
    }
}


