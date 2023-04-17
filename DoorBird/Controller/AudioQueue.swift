//
//  AudioQueue.swift
//  DoorBird
//
//  Created by Admin on 12/04/2023.
//

import Foundation
import UIKit


class AudioQueue {
    
    public typealias AudioListener = ([Int16]) -> Void
    
    private static let u2l: [Int16] = [-32124, -31100, -30076, -29052, -28028, -27004, -25980, -24956, -23932, -22908, -21884, -20860, -19836, -18812, -17788, -16764, -15996, -15484, -14972, -14460,-13948, -13436, -12924, -12412, -11900, -11388, -10876, -10364, -9852, -9340, -8828, -8316, -7932, -7676,-7420, -7164, -6908, -6652, -6396, -6140, -5884, -5628, -5372, -5116, -4860, -4604,-4348, -4092, -3900, -3772, -3644, -3516, -3388, -3260, -3132, -3004, -2876, -2748, -2620, -2492, -2364, -2236, -2108,-1980, -1884, -1820, -1756, -1692, -1628, -1564, -1500, -1436, -1372, -1308, -1244, -1180, -1116, -1052, -988, -924, -876, -844, -812, -780, -748, -716, -684, -652, -620, -588, -556, -524,-492, -460, -428, -396, -372, -356, -340, -324, -308, -292, -276, -260, -244, -228, -212, -196, -180, -164, -148, -132, -120, -112, -104, -96, -88, -80, -72, -64, -56, -48, -40, -32, -24, -16,-8, 0, 32124, 31100, 30076, 29052, 28028, 27004, 25980, 24956, 23932, 22908, 21884, 20860, 19836, 18812, 17788,16764, 15996, 15484, 14972, 14460, 13948, 13436, 12924, 12412, 11900, 11388, 10876, 10364, 9852, 9340, 8828, 8316, 7932, 7676, 7420, 7164, 6908, 6652, 6396, 6140, 5884, 5628, 5372, 5116, 4860,4604, 4348, 4092, 3900, 3772, 3644, 3516, 3388, 3260, 3132, 3004, 2876, 2748, 2620, 2492, 2364, 2236, 2108, 1980, 1884, 1820, 1756, 1692, 1628, 1564, 1500, 1436, 1372, 1308, 1244, 1180, 1116,1052, 988, 924, 876, 844, 812, 780, 748, 716, 684,652, 620, 588, 556, 524, 492, 460, 428, 396, 372, 356, 340,324, 308, 292,276, 260, 244, 228, 212, 196, 180, 164, 148, 132, 120, 112,104,96,88,80, 72, 64, 56, 48, 40, 32, 24, 16, 8, 0]
    private static let l2uexp = [
           0, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3,
           4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
           5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
           5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
           5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6,
           6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
           6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
           6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
           6, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,7, 7,7, 7, 7, 7, 7, 7, 7, 7, 7,7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7]

    public static let l2u: [Int8] = generateL2u().map { Int8(bitPattern: $0) }
    
    class Frame: Comparable, Hashable {
        let seq: Int
        let ulaw: [UInt8]
        let r: Int
        
        init(seq: Int, ulaw: [UInt8], r: Int) {
            self.seq = seq
            self.ulaw = ulaw
            self.r = r
        }
        
        static func < (lhs: Frame, rhs: Frame) -> Bool {
            return lhs.seq < rhs.seq
        }
        
        static func == (lhs: Frame, rhs: Frame) -> Bool {
            return lhs.seq == rhs.seq
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(seq)
        }
    }
    
    
    private var buffer = Heap<Frame>(comparer: { $0.seq < $1.seq })
    private var decodeQueue = [AudioQueue.Frame]()
    var audioCount = 0
    var lastAudioSeq = 0
    var lastDelivered = 0
    let decodeQueueLock = NSLock()
    
    func reset() {
        decodeQueueLock.lock()
                defer {
        decodeQueueLock.unlock()
        }

        buffer.clear()
        decodeQueue.removeAll()
        audioCount = 0
        lastAudioSeq = 0
    }
    
    func enqueue(seq: Int, ulaw: [UInt8], r: Int) {
        if seq < 50 * 5 && lastDelivered > seq + 5 * 50 {
            // assume reset
            lastDelivered = 0
        }
        if seq < lastDelivered {
            return
        }
        
        let f = Frame(seq: seq, ulaw: ulaw, r: r)
        if self.buffer.items.contains(where: { $0.seq == f.seq }) {
               return
           }
        buffer.insert(f)
        while (buffer.count == 0) && (buffer.peek()?.seq == lastDelivered + 1 || buffer.count > 30) {
            audioCount += 1
            let sf = buffer.remove()!
            lastDelivered = sf.seq
//            synchronized(decodeQueue) {
//                decodeQueue.offer(sf)
//                decodeQueue.notify()
//            }
            DispatchQueue.global(qos: .userInteractive).sync {
                       self.decodeQueue.append(sf)
//                self.decodeQueue.notify()
                   }
            
        }
    }
    
    func startDecoding(audioListener: @escaping AudioListener) {
        reset()
        DispatchQueue.global().async {
            while true {
                var ulawFrame: Frame?
                DispatchQueue.global(qos: .userInteractive).sync {
                                if self.decodeQueue.isEmpty {
                                    return
                    }
                    ulawFrame = self.decodeQueue.removeFirst()
                }
                
                guard let frame = ulawFrame else { return }
                let ulawLength = frame.ulaw.count
                let downsampling = 1
                var pcm = [Int16](repeating: 0, count: ulawLength + ulawLength % downsampling)
                
                let gainFactor = 1
                for (p, u) in stride(from: 0, to: pcm.count, by: downsampling).enumerated() {
                    var e = Int(Double(AudioQueue.u2l[Int(frame.ulaw[min(u, ulawLength - 1)]) & 0xff]) * Double(gainFactor))
                    if e > 0x7fff {
                        e = 0x7fff
                    } else if e < -0x7fff {
                        e = -0x7fff
                    }
                    pcm[p] = Int16(e)
                }
                
                audioListener(pcm)
            }
        }
    }
    
    private static func generateL2u() -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 64 * 1024)
        for i in 0..<result.count {
            result[i] = l2u(Int16(i))
        }
        return result
    }

    private static func l2u(_ sample: Int16) -> UInt8 {
        print(sample.hashValue)
        let cBias: Int16 = 0x84
        let cClip: Int16 = 32635
        let sign = ((~sample) >> 8) & 0x80
        var uSample = sample
        if sign == 0 {
            uSample = -sample
        }
        if uSample > cClip {
            uSample = cClip
        }
        uSample = uSample + cBias
        let exponent = l2uexp[(Int(uSample) >> 7) & 0xff]
        let mantissa = (Int(uSample) >> (exponent + 3)) & 0x0f
        let compressedByte = ~(Int(sign) | (exponent << 4) | mantissa)
        return UInt8((10))
    }
}



public class Heap<T> {
    var items = [T]()
    var comparer: (T,T) -> Bool

    init(comparer: @escaping (T,T) -> Bool) {
        self.comparer = comparer
    }

    var count: Int {
        return items.count
    }

    func push(_ value: T) {
        items.append(value)
        shiftUp(items.count - 1)
    }
    
    func insert(_ value: T) {
        items.append(value)
        shiftUp(items.count - 1)
       }

    func pop() -> T? {
        if items.isEmpty {
            return nil
        }
        else if items.count == 1 {
            return items.remove(at: 0)
        }
        else {
            let value = items[0]
            items[0] = items.remove(at: items.count - 1)
            shiftDown(0)
            return value
        }
    }

    func peek() -> T? {
        return items.first
    }
    
    public func remove() -> T? {
            if items.isEmpty {
                return nil
            }
            let first = items[0]
            let last = items.remove(at: count - 1)
            if !items.isEmpty {
                items[0] = last
                shiftDown(0)
            }
            return first
        }

    func clear() {
        items.removeAll(keepingCapacity: false)
    }
    


    func shiftUp(_ index: Int) {
        var childIndex = index
        let child = items[childIndex]
        var parentIndex = (childIndex - 1) / 2
        while childIndex > 0 && comparer(child, items[parentIndex]) {
            items[childIndex] = items[parentIndex]
            childIndex = parentIndex
            parentIndex = (childIndex - 1) / 2
        }
        items[childIndex] = child
    }

    func shiftDown(_ index: Int) {
        let count = items.count
        var parentIndex = index
        let parent = items[parentIndex]
        while true {
            let leftChildIndex = 2 * parentIndex + 1
            let rightChildIndex = 2 * parentIndex + 2
            var candidateIndex = parentIndex
            var candidate = parent
            if leftChildIndex < count {
                let leftChild = items[leftChildIndex]
                if comparer(leftChild, candidate) {
                    candidateIndex = leftChildIndex
                    candidate = leftChild
                }
            }
            if rightChildIndex < count {
                let rightChild = items[rightChildIndex]
                if comparer(rightChild, candidate) {
                    candidateIndex = rightChildIndex
                    candidate = rightChild
                }
            }
            if candidateIndex == parentIndex {
                break
            }
            items[parentIndex] = candidate
            items[candidateIndex] = parent
            parentIndex = candidateIndex
        }
    }
}
