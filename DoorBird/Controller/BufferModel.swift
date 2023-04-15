//
//  BufferModel.swift
//  DoorBird
//
//  Created by Admin on 12/04/2023.
//

import Foundation

class GCDAsyncUdpSocketPacketBuffers {
    var buffer: UnsafeMutablePointer<UInt8>
    var length: Int

    init(length: Int) {
        self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        self.length = length
    }

    deinit {
        buffer.deallocate()
    }

    static func newEmpty() -> GCDAsyncUdpSocketPacketBuffers {
        return GCDAsyncUdpSocketPacketBuffers(length: Int(UInt16.max))
    }

    static func withCapacity(capacity: Int) -> GCDAsyncUdpSocketPacketBuffers {
        return GCDAsyncUdpSocketPacketBuffers(length: capacity)
    }

    func setLength(newLength: Int) {
        if newLength > length {
            buffer.deallocate()
            buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: newLength)
            length = newLength
        }
    }
}

let GCDAsyncUdpSocketEmpty: Int32 = 0
let GCDAsyncUdpSocketUnused: Int32 = 1
let GCDAsyncUdpSocketRead: Int32 = 2





