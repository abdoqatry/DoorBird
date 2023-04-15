//
//  JpegQueu.swift
//  DoorBird
//
//  Created by Admin on 12/04/2023.
//

import Foundation

public protocol ImgListener {
       func imgReceived(_ imgData: Data)
   }

class JpegQueue {
   

    private var vSeq = 0
    private var vPresent = BitSet()
    private var vData = Data(count: 64 * 1024)
   

    func reset() {
        vSeq = 0
    }

    func enqueue(seq: Int, data: Data, imgListener: ImgListener) {
        var bb = ByteBuffer(data: data)
        if seq > vSeq {
            imgListener.imgReceived(data) // marker for incomplete image (broken image)
            vPresent.clear()
            vSeq = seq
            vData = Data(count: 0)
        }
        if seq == vSeq {
            let header = data.subdata(in: 6..<10)
            bb = ByteBuffer(data: header)
            let imageLen = bb.getInt(from: data)
            if vData.count != imageLen {
                vPresent.clear()
                vData = Data(count: imageLen)
            }
            bb = ByteBuffer(data: data.subdata(in: 10..<data.count))
            var imageOffset = bb.getInt(from: data)
            while bb.remaining > 0 {
                let blockSize = min(bb.remaining, 256)
                var chunk = data.subdata(in: imageOffset..<imageOffset+blockSize)
                chunk.withUnsafeMutableBytes { destBytes in
                    vData[imageOffset..<imageOffset+blockSize].copyBytes(to: destBytes, count: blockSize)
                }
                vPresent.set(imageOffset / 256)
                imageOffset += blockSize
            }
            if vPresent.nextClearBit(0) > imageLen / 256 {
                // image complete
                imgListener.imgReceived(vData)
                vData = Data(count: 0)
                vPresent.clear()
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
            vPresent.clear()
            vSeq = seq
            vData = Data(count: 0)
        }
        if seq == vSeq {
            imgListener.imgReceived(Data())
        }
    }
    
}

// BitSet implementation

class BitSet {
    private var bits = [UInt64]()

    func clear() {
        bits.removeAll()
    }

    func set(_ index: Int) {
        let wordIndex = index / 64
        if wordIndex >= bits.count {
            bits.append(contentsOf: Array(repeating: 0, count: wordIndex - bits.count + 1))
        }
        bits[wordIndex] |= (1 << UInt64(index % 64))
    }

    func nextClearBit(_ fromIndex: Int) -> Int {
        var i = fromIndex
        while i / 64 < bits.count {
            let word = bits[i / 64]
            if (word & (1 << UInt64(i % 64))) == 0 {
                return i
            }
            i += 1
        }
        return i
    }
}

// ByteBuffer implementation


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

    func getInt(from data: Data) -> Int {
        var value: Int = 0
        let bytes = getBytes(length: MemoryLayout<Int>.size)
        memcpy(&value, bytes.baseAddress, MemoryLayout<Int>.size)
        return value
    }
}
