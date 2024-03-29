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
    private var vData = Data(count: 64 * 1024)

    func reset() {
        vSeq = 0
    }

    
    
    func enqueue(seq: Int, data: Data, imgListener: ImgListener) {
        var bb = data.withUnsafeBytes { Data(Array($0)).map { UInt8($0) } }
        if seq > vSeq {
            imgListener.imgReceived(Data(count: 0))
            vPresent = IndexSet()
            vSeq = seq
            vData = Data(count: max(64 * 1024, data.count - 6))
        }
        if seq == vSeq {
            var index = 6
//            let imageLen = bytes.withUnsafeBytes { $0.load(as: Int32.self) }.bigEndian
            let imageLen = data.subdata(in: index..<index+4).withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
            index += 4
            if vData.count != imageLen {
                vPresent = IndexSet()
                vData = Data(count: max(Int(imageLen), data.count - 6))
            }
            var imageOffset = data.subdata(in: index..<index+4).withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
            index += 4
            var remaining = data.count - index
            while remaining > 0 {
                let blockSize = min(remaining, 256)
                let viewedData = data.subdata(in: index..<index+blockSize)
                let rangeStart = imageOffset
                let rangeEnd = Int(imageOffset)+blockSize
//                if rangeEnd <= vData.count {
                vData.replaceSubrange(Data.Index(rangeStart)..<rangeEnd, with: viewedData)
//                } else {
//                    print("Error: range exceeds vData bounds")
//                }
                index += blockSize
                remaining = data.count - index
//                vPresent[Int(imageOffset / 256) ] = true
                vPresent.insert(integersIn: Int(imageOffset) / 256..<Int(imageOffset) / 256 + blockSize / 256)
                imageOffset += Int32(blockSize)
            }
            if vPresent.count >= Int(imageLen) / 256 {
                // Image complete
                let imageData = Data(vData).withUnsafeBytes { Data(Array($0)).map { UInt8($0) } }
                let data = NSData(bytes: imageData, length: imageData.count)
                imgListener.imgReceived(data as Data)

                vData = Data(count: 0)
                vPresent = IndexSet()
                vSeq += 1
            }
        }
    }
    
    /**
     * Should not be necessary for normal use of doorstations with camera
     */
    func enqueueNoVideo(seq: Int, imgListener: ImgListener) {
        if seq > vSeq {
            imgListener.imgReceived(Data()) // marker for incomplete image
            vPresent = IndexSet()
            vSeq = seq
            vData = Data(count: 0)
        }
        if seq == vSeq {
            imgListener.imgReceived(Data())
        }
    }

}

// bitSet
//struct BitSet {
//    private var bits: [UInt64]
//
//    init(_ size: Int) {
//        bits = Array(repeating: 0, count: (size + 63) / 64)
//    }
//
//    subscript(index: Int) -> Bool {
//        get {
//            precondition(index >= 0 && index < bits.count * 64, "Index out of range")
//            return (bits[index / 64] & (1 << (index % 64))) != 0
//        }
//        set {
//            precondition(index >= 0 && index < bits.count * 64, "Index out of range")
//            if newValue {
//                bits[index / 64] |= (1 << (index % 64))
//            } else {
//                bits[index / 64] &= ~(1 << (index % 64))
//            }
//        }
//    }
//
//    func firstIndex(of value: Bool) -> Int? {
//        let mask = value ? 0xffffffff : 0x0
//        for i in 0..<bits.count {
//            let bitSet = bits[i]
//            if bitSet != mask {
//                let bitIndex = bitSet.trailingZeroBitCount
//                return i * 64 + bitIndex
//            }
//        }
//        return nil
//    }
//
//    mutating func clearAll() {
//        bits = Array(repeating: 0, count: bits.count)
//    }
//}

//extension Int {
//    var byteSize: String {
//        return ByteCountFormatter().string(fromByteCount: Int64(self))
//    }
//}


//extension Data {
//    func readInteger<T: FixedWidthInteger>(at index: Int) -> T {
//        var value: T = 0
//        self.withUnsafeBytes { bytes in
//            memcpy(&value, bytes.baseAddress?.advanced(by: index), MemoryLayout<T>.size)
//        }
//        return value
//    }
//}


//extension Data {
//    var uint8List: [UInt8] {
//        return [UInt8](self)
//    }
//}





