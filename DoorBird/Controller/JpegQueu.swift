////
////  JpegQueu.swift
////  DoorBird
////
////  Created by Admin on 12/04/2023.
////
//
import Foundation
public protocol ImgListener {
       func imgReceived(_ imgData: Data)
   }

class JpegQueue {


    private var vSeq = 0
    private var vPresent = IndexSet(integersIn: 0..<256)
//    var vPresent: Set<Int> = Set(0..<256)
    private var vData = Data(count: 64 * 1024)


    func reset() {
        vSeq = 0
    }


//    func enqueue(seq: Int, bb: Data, imgListener: ImgListener) {
//        if seq > vSeq {
//            imgListener.imgReceived(Data()) // marker for incomplete image (broken image)
//            vPresent.removeAll()
//            vSeq = seq
//            vData = Data(count: vData.count)
//        }
//        if seq == vSeq {
//            var index =
////            guard bb.count >= index + MemoryLayout<Int32>.size else {
////
////                return // not enough bytes to read imageLen
////            }
//            let imageLen = bb.withUnsafeBytes {$0.load(fromByteOffset: index, as: Int32.self) }
//            index += 4
//            if vData.isEmpty || imageLen != vData.count {
//                vPresent.removeAll()
//                vData = Data(count: Int(imageLen))
//            }
//
//            var imageOffset = bb.withUnsafeBytes { $0.load(fromByteOffset: index, as: Int32.self) }
//            index += 4
//            var remaining = bb.count - index
//            while remaining > 0 {
//                let blockSize = min(remaining, 256)
//                let blockRange = index..<(index+blockSize)
//                let blockData = bb.subdata(in: blockRange)
//                vData.replaceSubrange(Data.Index(imageOffset)..<min(Int(imageOffset)+blockSize, Int(imageLen)), with: blockData)
//                index += blockSize
//                remaining = bb.count - index
//                vPresent.insert(Int(imageOffset) / 256)
//                imageOffset += Int32(blockSize)
//            }
//
//            if vPresent.firstIndex(where: { ($0 == 0) }) == nil {
//                // image complete
//                imgListener.imgReceived(vData)
//                vData = Data()
//                vPresent.removeAll()
//                vSeq += 1
//            }
//        }
//    }
    
    
    
    func enqueue(seq: Int, data: Data, imgListener: ImgListener) {
        var bb = data
           if seq > vSeq {
//               imgListener.imgReceived(Data(count: 0))
               vPresent = IndexSet()
               vSeq = seq
               vData = Data(count: max(64 * 1024, data.count - 6))
           }
           if seq == vSeq {
               var index = 0
               let imageLen = Int(bb.withUnsafeBytes { $0.load(fromByteOffset: (index / 4) * 4, as: Int32.self) })
               index += 4
               if vData.count != imageLen {
                   vPresent = IndexSet()
                   vData = Data(count: max(imageLen, data.count - 6))
               }
               var imageOffset = Int(bb.withUnsafeBytes { $0.load(fromByteOffset: (index / 4) * 4, as: Int32.self) })
               index += 4
               var remaining = bb.count - index
               while remaining > 0 {
                         let blockSize = min(remaining, 256)
                         let viewedData = bb.subdata(in: index..<index+blockSize)
                         let rangeStart = imageOffset
                         let rangeEnd = imageOffset+blockSize
                         if rangeEnd <= vData.count {
                        vData.replaceSubrange(rangeStart..<rangeEnd, with: viewedData)
                         } else {
                             print("Error: range exceeds vData bounds")
                         }
                         index += blockSize
                         remaining = bb.count - index
                         vPresent.insert(integersIn: imageOffset / 256..<imageOffset / 256 + blockSize / 256)
                         imageOffset += blockSize
                     }
//               if let clearBit = vPresent.firstIndex(of: false) {
              
//               if vPresent.firstIndex(where: { ($0 == 0) }) == nil {
               if vPresent.count >= Int(imageLen) / 256 {
                       // Image complete
                   let imageData = Data(Array(vData))
                   imgListener.imgReceived(imageData)
                       vData = Data(count: 0)
                       vPresent = IndexSet()
                       vSeq += 1
                   }
               }
//           }
        
    }


    
    
    /**
     * Should not be necessary for normal use of doorstations with camera
     */
    func enqueueNoVideo(seq: Int, imgListener: ImgListener) {
        if seq > vSeq {
            imgListener.imgReceived(Data()) // marker for incomplete image
            vPresent.removeAll()
            vSeq = seq
            vData = Data(count: 0)
        }
        if seq == vSeq {
            imgListener.imgReceived(Data())
        }
    }

}
//
//// ByteBuffer implementation
//
//
class ByteBuffer {
    private var data: Data
    private var position: Int

    init(data: Data) {
        self.data = data
        self.position = 0
    }

    var remaining: Int {
        return data.count - position
    }

    func getBytes(length: Int) -> UnsafeRawBufferPointer {
        let bytes = UnsafeRawBufferPointer(start: data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
            return pointer + position
        }, count: length)
        position += length
        return bytes
    }

//    func getInt(from data: Data) -> Int {
//        var value: Int = 0
//        let bytes = getBytes(length: MemoryLayout<Int>.size)
//        memcpy(&value, bytes.baseAddress, MemoryLayout<Int>.size)
//        return value
//    }
}

extension ByteBuffer {
    func getInt(from offset: Int) -> Int {
        guard self.data.count >= offset + MemoryLayout<Int>.size else {
            fatalError("Buffer too small")
        }
        let value = self.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in
            ptr.load(fromByteOffset: offset, as: Int.self)
        }
        return value.bigEndian
    }
}





extension Int {
    var byteSize: String {
        return ByteCountFormatter().string(fromByteCount: Int64(self))
    }
}
