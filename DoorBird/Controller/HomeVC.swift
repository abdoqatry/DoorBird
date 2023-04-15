//
//  HomeVC.swift
//  DoorBird
//
//  Created by Admin on 04/04/2023.
//

import UIKit
import Network
import AVFoundation
import CocoaAsyncSocket


class HomeVC: UIViewController, GCDAsyncUdpSocketDelegate,ImgListener  {
    
    var udpPort: UInt16 = 6999
    var udpAddress = "apiorun.doorbird.net"
    var encryptionKey = ""
    var sessionId = "XXDiNMqstOw7jy754170"
    var subscribeSeq :UInt8 = 0
    
    enum UdpConstants: UInt8 {
        case PACKET_SUBSCRIBE = 0x01
        case PACKET_STATE_CHANGE = 0x11
        case PACKET_ULAW = 0x21
        case PACKET_NO_AUDIO = 0x2F
        case PACKET_JPEG_V2 = 0x34
        case PACKET_NO_VIDEO = 0x3F
        case PACKET_ENCRYPTION_TYPE_1 = 0xE1
        static let FLAG_STATE: UInt8 = 1
        static let FLAG_AUDIO: UInt8 = 2
        static let FLAG_VIDEO: UInt8 = 4
        static let STATE_VIDEO_SESSION_INVALID: UInt8 = 5
        static let STATE_AUDIO_SESSION_INVALID: UInt8 = 6
    }
    
    private var udpSocket: GCDAsyncUdpSocket?
    private let CLOUD_API_ACCESS_TOKEN = "1dc6a6e11f7c86df5de7245b1974786e9ef62f989e1de0d59866984bb0903c4f"
    private let VIDEO_ENABLED = true
    private let AUDIO_SPEAKER_ENABLED = true
    private let AUDIO_MIC_ENABLED = true
    private let INFO_URL = "https://api.doorbird.io/live/info"
    private var requestedFlags: Int = 0
    private var currentFlags: Int = 0
    private var audioTransmitSequenceNumber: Int = 0
    private var encryptionNonce: Int64 = 1
    private var liveImageView: UIImageView!
//    private var audioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var jq = JpegQueue()
    private var aq = AudioQueue()
//    var audioPlayer: AVAudioPlayerNode?
    var audioEngine = AVAudioEngine()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        liveImageView = UIImageView()
        liveImageView.contentMode = .scaleAspectFit
        view.addSubview(liveImageView)
        
        // Request microphone permission from the user
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if !granted {
                    let alert = UIAlertController(title: "Microphone access required", message: "Please grant microphone access to use this app", preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(action)
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try audioSession.setMode(.voiceChat)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
      
        DispatchQueue.global(qos: .background).async { [self] in
            getInfo { (success) in
                if success {
            if AUDIO_SPEAKER_ENABLED {
           
            let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 8000, channels: 1, interleaved: false)!
                print(format)
                let input = self.audioEngine.inputNode
                let bus = 0
                let inputFormat = input.inputFormat(forBus: bus)
                
             let audioPlayer = AVAudioPlayerNode()
            self.audioEngine.attach(audioPlayer)
            self.audioEngine.connect(audioPlayer, to: self.audioEngine.mainMixerNode, format: inputFormat)
                try!self.audioEngine.start()
            audioPlayer.play()
                        
            self.aq.startDecoding(audioListener: { buffer in
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(buffer.count)) else { return }
            pcmBuffer.frameLength = pcmBuffer.frameCapacity
        let pcmBufferPointer = pcmBuffer.int16ChannelData![0]
                for i in 0 ..< buffer.count {
                    pcmBufferPointer[i] = Int16(buffer[i])
                }
                            audioPlayer.scheduleBuffer(pcmBuffer)
                        })
                    }
                    
                    if self.AUDIO_MIC_ENABLED {
                        transmitMic()
                    }
                self.runCamera()
                } else {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Info request failed", message: "Access token might not be valid", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
        
    }

      override func viewDidLayoutSubviews() {
          super.viewDidLayoutSubviews()
          liveImageView.frame = view.bounds
      }
    
    private func startCamera() {
           DispatchQueue.global(qos: .background).async {
               if true {
//                   self.runCamera()
               } else {
                   DispatchQueue.main.async {
                       let alertController = UIAlertController(title: "Info request failed", message: "Access token might not be valid", preferredStyle: .alert)
                       alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                       self.present(alertController, animated: true, completion: nil)
                   }
               }
           }
       }
    
    private func getInfo(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: INFO_URL) else {
            completion(false)
                    return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.addValue("Bearer \(CLOUD_API_ACCESS_TOKEN)", forHTTPHeaderField: "Authorization")
        request.addValue("active", forHTTPHeaderField: "cloud-mjpg")

        print(CLOUD_API_ACCESS_TOKEN)

        var success = false
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200, let data = data else {
                return
            }
            do {
                let mjpgInfo = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let defaultMjpg = mjpgInfo?["video"] as? [String: Any]??
                    ?? nil
                let mjpgDefault = defaultMjpg??["cloud"] as? [String: Any]??
                    ?? nil
                let mjpgCloud = mjpgDefault??["mjpg"] as? [String: Any]??
                    ?? nil
                let mjpg = mjpgCloud??["default"] as? [String: Any]??
                    ?? nil
                self.udpAddress = mjpg??["host"] as? String ?? ""
                self.udpPort = UInt16(mjpg??["port"] as? Int ?? 0)
                self.sessionId = mjpg??["session"] as? String ?? ""
                self.encryptionKey = mjpg??["key"] as? String ?? ""
                print(self.encryptionKey)
                completion(true)
            } catch {
                print(error.localizedDescription)
            }
        }
        task.resume()

        
    }
    
//    private func runCamera() {
//        do {
//            udpSocket = try! GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
//            try? udpSocket?.bind(toPort: 0)
//            try? udpSocket?.beginReceiving()
//
////            let dpIn = GCDAsyncUdpPacket(data: Data(count: 16 * 1024), withTimeout: -1, tag: 0)
//            if sessionId.starts(with: "Xnotrung") {
//                // nobody rang and watch always permission is not given to the user
//                udpSocket?.close()
//                return
//            }
//            var lastSubscribe: TimeInterval = 0
//                    aq.reset()
////            dpIn.address = udpAddress
////            var lastSubscribe: UInt64 = 0
//            aq.reset()
//            while true {
//                if let socket = udpSocket, socket.isClosed() {
//                    lastSubscribe = 0
//                    try! udpSocket?.bind(toPort: 0)
//                }
//                // if the requested flags did not change, only refresh the subscription every 15 seconds,
//                // if flags changed, it should be done earlier
//                if lastSubscribe + (currentFlags == requestedFlags ? 15000 : 500) < Date().timeIntervalSince1970 {
//                    lastSubscribe = Date().timeIntervalSince1970
//                    sendSubscribe(unsubscribe: false)
//                }
//                if let packet = try? udpSocket?.receiveOnce() {
//                    processPacket(packet)
//                }
//
//            }
//        } catch {
//            // add exception handling / reconnects / ui information
//            print(error)
//        }
//    }
    
    private func runCamera() {
        do {
            udpSocket = try GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
            try udpSocket?.bind(toPort: 0)
            try udpSocket?.beginReceiving()

            if sessionId.starts(with: "Xnotrung") {
                // Nobody rang and watch always permission is not given to the user.
                udpSocket?.close()
                return
            }

            var lastSubscribe: TimeInterval = 0
            aq.reset()

            while true {
                if let socket = udpSocket, socket.isClosed() {
                    lastSubscribe = 0
                    try udpSocket?.bind(toPort: 0)
                }

                // If the requested flags did not change, only refresh the subscription every 15 seconds,
                // if flags changed, it should be done earlier.
                if lastSubscribe + (currentFlags == requestedFlags ? 15000 : 500) < Date().timeIntervalSince1970 {
                    lastSubscribe = Date().timeIntervalSince1970
                    sendSubscribe(unsubscribe: false)
                }
                
              
//                // Receive data from the socket.
//                var data = Data()
//                var sourceAddress: Data?
//                udpSocket?.receive(&data, fromAddress: &sourceAddress, withTimeout: -1, tag: 0)
//
//                // Pass the received data to the packet processing function.
//                processPacket(data: data, sourceAddress: sourceAddress)
            }
        } catch {
            // Handle errors, e.g. by reconnecting.
            print("Error: \(error)")
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        processPacket(data, sourceAddress: address)
       
    }

    private func processPacket(_ packetData: Data, sourceAddress: Data?) {
        var packetData = packetData
        var dataLength = packetData.count
        let type = packetData[0]
        var data: Data? = nil
        if (type == UdpConstants.PACKET_ENCRYPTION_TYPE_1.rawValue) {
            let nonce = packetData.subdata(in: 1..<9)
            let encryptedData = packetData.subdata(in: (nonce.count+1)..<dataLength)
            if let decryptedData = SodiumEncryption.decrypt(
                encryptionType: SodiumEncryption.EncryptionType.chacha20_poly1305,
                cypher: [UInt8](encryptedData),
                nonce: [UInt8](nonce),
                password: [UInt8](encryptionKey.data(using: .utf8)!)
            ) {
                data = Data(decryptedData)
                dataLength = data!.count
            }
        }
        if let data = data {
            var type = data[0]
            var seq = Int((UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | UInt32(data[3]))
            let state = data[4]
            let flags = data[5]

            switch (type) {
            case UdpConstants.PACKET_STATE_CHANGE.rawValue:
                if (state == UdpConstants.STATE_VIDEO_SESSION_INVALID) {
                    // handle video session invalid state
                } else if (state == UdpConstants.STATE_AUDIO_SESSION_INVALID) {
                    // handle audio session invalid state
                }
            case UdpConstants.PACKET_ULAW.rawValue:
                var i = 6
                var r = 0
                let length = 160
                while i < data.count {
                    let type = data[i]
                    let seqByte1 = Int(data[i+1])
                    let seqByte2 = Int(data[i+2])
                    let seqByte3 = Int(data[i+3])
                    seq = (seqByte1 << 16) | (seqByte2 << 8) | seqByte3
                    let state = data[i+4]
                    let flags = data[i+5]
                    let ulaw = data.subdata(in: (i+6)..<(i+6+length))
                    i += 6 + length

                    aq.enqueue(seq: seq, ulaw: [UInt8](ulaw), r: r)
                    r += 1
                }
            case UdpConstants.PACKET_JPEG_V2.rawValue:
                let jpegData = data.subdata(in: 6..<dataLength)
                jq.enqueue(seq: seq, data: jpegData, imgListener:self)
            case UdpConstants.PACKET_NO_VIDEO.rawValue:
                jq.enqueueNoVideo(seq: seq, imgListener: self)
            default:
                // unknown packet
                break
            }
        } else {
            print("could not decrypt packet")
        }
    }


    
    private func transmitAudioData(audioData: [Int16]) {
        if audioData.count != 160 {
            print("Transmit: must be of size 160")
            return
        }
        
        var ulaw = [UInt8](repeating: 0, count: audioData.count)
        for i in 0..<audioData.count {
            // conversion via mapping table from pcm to u-law 8kHz
            ulaw[i] = UInt8(AudioQueue.l2u[Int(audioData[i]) & 0xffff])
            
        }
        
        var audioOutPacket = [UInt8](repeating: 0, count: 164)
        var i = 0
        audioOutPacket[i] = (UdpConstants.PACKET_ULAW).rawValue
        audioOutPacket[i+1] = UInt8(audioTransmitSequenceNumber >> 16)
        audioOutPacket[i+2] = UInt8(audioTransmitSequenceNumber >> 8)
        audioOutPacket[i+3] = UInt8(audioTransmitSequenceNumber)
        for j in 0..<ulaw.count {
            audioOutPacket[i+4+j] = ulaw[j]
        }
        audioTransmitSequenceNumber += 1
        
        do {
            try sendEncryptedPacket(data: audioOutPacket)
        } catch {
            print("Error sending encrypted packet")
        }
    }
    
    
    private func transmitMic() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetooth])
            try audioSession.setMode(.voiceChat)
            try audioSession.setPreferredSampleRate(8000)
            try audioSession.setPreferredIOBufferDuration(0.02)
        } catch {
            print("Error setting audio session category or mode: \(error.localizedDescription)")
            return
        }
        
        let audioEngine = AVAudioEngine()
        let audioInput = audioEngine.inputNode
        
        let bus = 0
//        let inputFormat = audioInput.inputFormat(forBus: bus)
        
        
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                           sampleRate: 8000,
                                           channels: 1,
                                           interleaved: false)!
          let input = audioEngine.inputNode
         
          let inputFormat = input.outputFormat(forBus: bus)
              
          let bufferSize = inputFormat.sampleRate * 0.1
        
        
        let audioPlayer = AVAudioPlayerNode()
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: inputFormat)
       
        
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            return
        }
        
        audioInput.installTap(onBus: 0, bufferSize: UInt32(bufferSize), format: inputFormat) { (buffer, time) in
            
        
            let convertedBuffer = self.convertBuffer(buffer: buffer, from: inputFormat, to: outputFormat)
            let data =  UnsafeBufferPointer(start: convertedBuffer.int16ChannelData![0], count: 160)

            self.transmitAudioData(audioData: Array(data))
//                }
            
           
            
            audioPlayer.play()
            
            audioEngine.prepare()
        }
    }

    func convertBuffer(buffer: AVAudioPCMBuffer,
                       from inputFormat: AVAudioFormat,
                       to outputFormat: AVAudioFormat) -> AVAudioPCMBuffer {
            
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)!
            
        let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
            
        let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate))!
            
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
        assert(status != .error)
            
        return convertedBuffer
    }


    
    private func sendEncryptedPacket(data: [UInt8]) throws {
        if data.count < 4 {
            throw NSError(domain: "invalid packet", code: data.count, userInfo: nil)
        }

        var nonceData = [UInt8](repeating: 0, count: 8)
        for i in 0..<nonceData.count {
            nonceData[i] = UInt8(encryptionNonce >> (i * 8))
        }
        let cypher = SodiumEncryption.encrypt(encryptionType: .chacha20_poly1305, plain: data, nonce: nonceData, password: Array(encryptionKey.utf8))
        
        var encryptedPacket = [UInt8](repeating: 0, count: cypher!.count + nonceData.count + 1)
        encryptedPacket[0] = (UdpConstants.PACKET_ENCRYPTION_TYPE_1).rawValue
        for i in 0..<nonceData.count {
            encryptedPacket[i+1] = nonceData[i]
        }
        for i in 0..<cypher!.count {
            encryptedPacket[i+nonceData.count+1] = cypher![i]
        }
        let packetData = Data(encryptedPacket)
        udpSocket?.send(packetData, toHost: udpAddress, port: udpPort, withTimeout: -1, tag: 0)
        encryptionNonce += 1
    }



    
           
    
    
    /*
    * Sends a packet to the server, packet should already be encrypted.
    */
    private func sendPacket(data: Data, length: Int) throws {
         udpSocket?.send(data, toHost: udpAddress, port: UInt16(udpPort), withTimeout: -1, tag: 0)
    }

    
    /*
    * Subscription handling should be done frequently. It defines which type of data are requested.
    * Can be just video or video and audio.
    */
    private func sendSubscribe(unsubscribe: Bool) {
        var subscribe: UInt8 = 0
        var videoType: UInt8 = UdpConstants.PACKET_NO_VIDEO.rawValue
        var audioType: UInt8 = UdpConstants.PACKET_NO_AUDIO.rawValue
        subscribe |= UdpConstants.FLAG_STATE
        if !unsubscribe {
            if VIDEO_ENABLED {
                subscribe |= UdpConstants.FLAG_VIDEO
                (videoType = UdpConstants.PACKET_JPEG_V2.rawValue)
            }
            if AUDIO_SPEAKER_ENABLED {
                subscribe |= UdpConstants.FLAG_AUDIO
                (audioType = UdpConstants.PACKET_ULAW.rawValue)
            }
        }
        var bb = Data(count: 128)
        bb.withUnsafeMutableBytes { buffer in
            var bbPointer = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
            bbPointer?.pointee = (UdpConstants.PACKET_SUBSCRIBE).rawValue
            bbPointer = bbPointer?.advanced(by: 3)
            bbPointer?.assign(from: &subscribeSeq, count: MemoryLayout<UInt32>.size)
            bbPointer = bbPointer?.advanced(by: 1)
            let session = sessionId.data(using: .utf8)!
            bbPointer?.pointee = UInt8(session.count)
            bbPointer = bbPointer?.advanced(by: 1)
            session.copyBytes(to: bbPointer!, count: session.count)
            bbPointer = bbPointer?.advanced(by: session.count)
            bbPointer?.pointee = subscribe
            bbPointer = bbPointer?.advanced(by: 1)
            bbPointer?.pointee = videoType
            bbPointer = bbPointer?.advanced(by: 1)
            bbPointer?.pointee = audioType
        }

        subscribeSeq += 1
        try? sendPacket(data: bb, length: bb.count)
        requestedFlags = Int(subscribe)
    }
    
    private func unsubscribe() {
        do {
            // send unsubscribe multiple times if a udp packet gets lost
            for _ in 0..<3 {
                sendSubscribe(unsubscribe: true)
                Thread.sleep(forTimeInterval: 0.02)
            }
        } catch {
            print(error)
        }
    }
    
    
    func imgReceived(_ imgData:Data) {
        print("Image received: \(imgData.count)")
        // Decode JPEG into bitmap to display it in image view
        if let bitmap = UIImage(data: imgData) {
            DispatchQueue.main.async {
                self.liveImageView.image = bitmap
            }
        }
    }
    

}



