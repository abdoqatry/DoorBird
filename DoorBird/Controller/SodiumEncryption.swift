//
//  SodiumEncryption.swift
//  DoorBird
//
//  Created by Admin on 12/04/2023.
//

import Foundation
import Sodium
//public class SodiumEncryption {
//    public static let ENCRYPTION_ENCODING = "US-ASCII"
//    public static let ADD_BYTE_LENGTH_CHACHA20_POLY_1305 = 16
//
    public enum EncryptionType {
        case none
        case chacha20_poly1305
    }

//    /**
//     Decrypts a plain text with given encryption type
//
//     - Parameters:
//        - encryptionType: encryption type
//        - cypher: cipher text
//        - nonce: nonce
//        - password: password
//     - Returns: the decrypted data
//     */
//    public static func decrypt(encryptionType: EncryptionType, cypher: [UInt8], nonce: [UInt8], password: [UInt8]) -> [UInt8]? {
//           do {
//               let sodium = Sodium()
//               var decrypted: [UInt8]?
//               var output: Data
//               let outLen = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
//               var result: Int32 = -1
//
//               output = Data(count: sodium.aead.xchacha20poly1305ietf)
//               switch encryptionType {
//               case .chacha20_poly1305:
//
//                   if !cypher.isEmpty && !nonce.isEmpty && !password.isEmpty {
//                       let key = sodium.secretBox.key()
//                       print("nonce = \(nonce)")
//                       print("password = \(password)")
//                       print("cypher = \(cypher)")
//
//                       decrypted = sodium.aead.xchacha20poly1305ietf.decrypt(
//                           authenticatedCipherText: cypher,
//                           secretKey: password,
//                           nonce: nonce
//                    )
//                       print(decrypted)
////                       result = 0
//                   }
//               default:
//                   break
//               }
//
////               if result == 0 {
//                   return decrypted
////               }
//           } catch {
//               print(error)
//           }
//
//           return nil
//       }
//
//
//
//
//
//
////    /**
////     Encrypts a plain text with given encryption type
////
////     - Parameters:
////        - encryptionType: encryption type
////        - plain: plain text bytes
////        - nonce: nonce bytes
////        - password: password bytes
////     - Returns: the encrypted text bytes
////     */
//    public static func encrypt(encryptionType: EncryptionType, plain: [UInt8], nonce: [UInt8], password: [UInt8]) -> [UInt8]? {
//           do {
//               var output: [UInt8]?
//               var result = -1
//
//               switch encryptionType {
//               case .chacha20_poly1305:
//                   let sodium = Sodium()
//                   if plain.count > 0 && nonce.count == sodium.aead.xchacha20poly1305ietf.NonceBytes && password.count == sodium.secretBox.KeyBytes {
//                       let key =  sodium.secretBox.key()
//                       output =  sodium.aead.xchacha20poly1305ietf.encrypt(
//                           message: plain,
//                           secretKey: key
//                       )
//                       result = 0
//                   }
//               default:
//                   break
//               }
//
//               if result == 0 {
//                   return output
//               }
//           } catch {
//               print(error)
//           }
//
//           return nil
//       }
//
//   }

    
    
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


