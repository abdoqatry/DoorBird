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
import Accelerate


class HomeVC: UIViewController, GCDAsyncUdpSocketDelegate,ImgListener{

    var udpPort: UInt16 = 9000
    var udpAddress = "192.168.1.10"
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
    static var CLOUD_API_ACCESS_TOKEN = ""
    private let VIDEO_ENABLED = true
    private let AUDIO_SPEAKER_ENABLED = true
    private let AUDIO_MIC_ENABLED = true
    private let INFO_URL = "https://api.doorbird.io/live/info"
    private var requestedFlags: Int = 0
    private var currentFlags: Int = 0
    private var audioTransmitSequenceNumber: Int = 0
    private var encryptionNonce: Int64 = 1
    private var liveImageView: UIImageView!
    private let audioSession = AVAudioSession.sharedInstance()
    private var jq = JpegQueue()
    private var aq = AudioQueue()
    var audioEngine = AVAudioEngine()
    var converter = AVAudioConverter()


    override func viewDidLoad() {
        super.viewDidLoad()
        askPermissionIfNeeded()
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
            try audioSession.setMode(.default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }


        DispatchQueue.global(qos: .background).async { [self] in
            getInfo { (success) in
                if success {
                    if self.AUDIO_SPEAKER_ENABLED {

                let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)!

                let audioPlayer = AVAudioPlayerNode()
                self.audioEngine.attach(audioPlayer)
                self.audioEngine.connect(audioPlayer, to: self.audioEngine.mainMixerNode, format: format)
                try!self.audioEngine.start()
                audioPlayer.play()

                var sentList :[Int16] = []
                self.aq.startDecoding(audioListener: { buffer in


                    if(sentList.count > 20000){
                        self.setupAudioPlayer(sentList)
                        sentList.removeAll()
                    }
                    else {
                sentList.append(contentsOf: buffer)
                    }

                        })
                    }

                     if self.AUDIO_MIC_ENABLED {
                        self.transmitMic()
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



    func askPermissionIfNeeded() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSession.RecordPermission.granted:
            print("Permission granted")
        case AVAudioSession.RecordPermission.denied:
            print("Pemission denied")
        case AVAudioSession.RecordPermission.undetermined:
            print("Request permission here")
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                // Handle granted
            })
        @unknown default: break

        }

    }

    func setupAudioPlayer(_ int16Buffer: [Int16]){
            var pcmFloatData: [Float] = []

                let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 8000 , channels: 1)!
                let frameCapacity = AVAudioFrameCount(int16Buffer.count)
                if let pcmBuf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCapacity) {
                    let monoChannel = pcmBuf.floatChannelData![0]
                    pcmFloatData = [Float](repeating: 0.0, count: int16Buffer.count)

                    // Int16 ranges from -32768 to 32767 -- we want to convert and scale these to Float values between -1.0 and 1.0
                    var scale = Float(Int16.max) + 1.0
                    vDSP_vflt16(int16Buffer, 1, &pcmFloatData, 1, vDSP_Length(int16Buffer.count)) // Int16 to Float
                    vDSP_vsdiv(pcmFloatData, 1, &scale, &pcmFloatData, 1, vDSP_Length(int16Buffer.count)) // divide by scale

                    memcpy(monoChannel, pcmFloatData, MemoryLayout<Float>.size * Int(int16Buffer.count))
                    pcmBuf.frameLength = frameCapacity

                    let audioPlayer = AVAudioPlayerNode()
                    audioEngine.attach(audioPlayer)
                    let audioMixer = audioEngine.mainMixerNode
                    audioEngine.connect(audioPlayer, to: audioMixer, format: audioFormat)
                    audioPlayer.volume = 1

                    let audioSession = AVAudioSession.sharedInstance()

                    do {
                        try audioSession.setCategory(.playAndRecord)

                    try audioSession.overrideOutputAudioPort(.speaker)
                    } catch let error {
                        print("Error setting audio session category: \(error.localizedDescription)")
                    }

                    audioPlayer.scheduleBuffer(pcmBuf)

                    do {
                         audioEngine.prepare()
                        try audioEngine.start()
                    } catch let error {
                        print("Error starting audio engine: \(error.localizedDescription)")
                    }
                    audioPlayer.play()
                }
        }

      override func viewDidLayoutSubviews() {
          super.viewDidLayoutSubviews()
          liveImageView.frame = view.bounds
      }

    private func startCamera() {
           DispatchQueue.global(qos: .background).async {
               if true {
                   self.runCamera()
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
        request.addValue("Bearer \(HomeVC.CLOUD_API_ACCESS_TOKEN)", forHTTPHeaderField: "Authorization")
        request.addValue("active", forHTTPHeaderField: "cloud-mjpg")


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
                print( "Encryption Key is \(self.encryptionKey) ")
                completion(true)
            } catch {
                print(error.localizedDescription)
            }
        }
        task.resume()


    }

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

            }
        } catch {
            // Handle errors, e.g. by reconnecting.
            print("Error: \(error)")
        }
    }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        processPacket(data, sourceAddress: address)

    }

    func validateJPEGHeader(_ imageData: Data) -> Bool {
        let expectedHeader: [UInt8] = [0xFF, 0xD8, 0xFF]
        guard imageData.count >= 3 else {
            return false
        }
        let header = [UInt8](imageData.prefix(3))
        return header == expectedHeader
    }

    private func processPacket(_ packetData: Data, sourceAddress: Data?) {
        let packetData = packetData
        var dataLength = packetData.count
        let type = packetData[0]
        var data: Data? = nil
        if (type == UdpConstants.PACKET_ENCRYPTION_TYPE_1.rawValue) {
            let nonce = packetData.subdata(in: 1..<9)
            let encryptedData = packetData.subdata(in: (nonce.count+1)..<dataLength)
            if let decryptedData = SodiumEncryption.decrypt(
                cypher: [UInt8](encryptedData), cypherLen: encryptedData.count,
                nonce: [UInt8](nonce),
                password: [UInt8](encryptionKey.data(using: .utf8)!)
            ) {
                data = Data(decryptedData)
                dataLength = data!.count
            }
        }
        if let data = data {
            let type = data[0]
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
                var i = 0
                var r = 0
                let length = 160
                while i < length {
                    let type = data[i]
                    i+=1
                    let seqByte1 = Int(data[i])
                    i+=1
                    let seqByte2 = Int(data[i])
                    i+=1
                    let seqByte3 = Int(data[i])
                    i+=1
                    seq = (seqByte1 << 16) | (seqByte2 << 8) | seqByte3
                    let state = data[i]
                    i+=1
                    let flags = data[i]
                    i+=1
                    let subdata = data.subdata(in: i..<i+length)
                    let bufferPointer = UnsafeMutableBufferPointer<Int8>.allocate(capacity: length)
                    defer { bufferPointer.deallocate() }
                    _ = subdata.copyBytes(to: bufferPointer)
                    let ulaw = Array(bufferPointer)
//                        print("subdata\(ulaw)")

                    i += length

                    aq.enqueue(seq: seq, ulaw: ulaw, r: r)
                    r += 1
                }
            case UdpConstants.PACKET_JPEG_V2.rawValue:
                jq.enqueue(seq: seq, data: data, imgListener:self)
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

//        print("Single Value is \(AudioQueue.l2u)")

        for i in 0..<audioData.count {
            // conversion via mapping table from pcm to u-law 8kHz

            var index = Int32(Int32(audioData[i]) & Int32(0xffff))
//            print("Index is \(Int(index))")
            ulaw[i] = UInt8(truncatingIfNeeded: AudioQueue.l2u[Int(index)])

//            ulaw[i] = UInt8((AudioQueue.l2u[Int(audioData[i]) & 0xffff])) & 0xff

        }

        print("Audio Inout is \(ulaw)")
        var audioOutPacket = [UInt8](repeating: 0, count: 164)
        let i = 0
        audioOutPacket[i] = (UdpConstants.PACKET_ULAW).rawValue
        audioOutPacket[i+1] = UInt8(audioTransmitSequenceNumber >> 16)
        audioOutPacket[i+2] = UInt8(audioTransmitSequenceNumber >> 8)
        audioOutPacket[i+3] = UInt8(audioTransmitSequenceNumber & 0xff)
        for j in 0..<ulaw.count {
            audioOutPacket[i+4+j] = ulaw[j]
        }
        audioTransmitSequenceNumber += 1

        do {
            print("Audio Output Data is \(audioOutPacket)")


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

        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                           sampleRate: 8000,
                                           channels: 1,
                                           interleaved: false)!
          let input = audioEngine.inputNode

          let inputFormat = input.outputFormat(forBus: bus)

          let bufferSize = inputFormat.sampleRate * 0.1

        self.converter = AVAudioConverter(from: inputFormat, to: outputFormat)!


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


            let convertedBuffer = self.convertBuffer(buffer: buffer,outputFormat:outputFormat)
            print(convertedBuffer.format.sampleRate)

            // Check that the buffer contains 16-bit integer audio data
            guard  convertedBuffer.format.sampleRate == 8000 && convertedBuffer.format.channelCount == 1 && convertedBuffer.format.commonFormat == .pcmFormatInt16 else {
                // Handle error: buffer does not contain 16-bit integer audio data with 1 channel and a sample rate of 44.1 kHz
                return
            }

            // Get the Int16 data from the buffer
            let pcmData = Array(UnsafeBufferPointer(start: convertedBuffer.int16ChannelData?[0], count: Int(convertedBuffer.frameLength)))


            print("buffer int16 =\(pcmData.count)")
            let chunkSize = 160
//            var sentList :[Int16] = []
            for i in stride(from: 0, to: pcmData.count, by: chunkSize) {
                let startIndex = i
                let endIndex = min(i + chunkSize, pcmData.count)
                let chunk = Array(pcmData[startIndex..<endIndex])
                print("chunk is \(chunk)")

                self.transmitAudioData(audioData: chunk)

            }

            let data =  UnsafeBufferPointer(start: convertedBuffer.int16ChannelData![0], count: 160)


            self.transmitAudioData(audioData: Array(data))

            audioPlayer.play()

            audioEngine.prepare()
        }
    }

    func convertBuffer(buffer: AVAudioPCMBuffer,outputFormat:AVAudioFormat) -> AVAudioPCMBuffer {
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
//        encryptionNonce = 1

        var nonceData = [UInt8](repeating: 0, count: 8)
        for i in 0..<nonceData.count {
            nonceData[i] = UInt8((encryptionNonce >> (i * 8)) & 0xff)
            print("value = \(encryptionNonce >> (i * 8))")
            print("encryptionNonce = \(encryptionNonce)")

        }

        print("nonchData\(nonceData[0])")
        let cypher = SodiumEncryption.encrypt(plain: data, plainLen: data.count, nonce: nonceData, password: Array(encryptionKey.utf8))

        var encryptedPacket = [UInt8](repeating: 0, count: cypher!.count + nonceData.count + 1)
        encryptedPacket[0] = (UdpConstants.PACKET_ENCRYPTION_TYPE_1).rawValue
        for i in 0..<nonceData.count {
            encryptedPacket[i+1] = nonceData[i]

        }
        for i in 0..<cypher!.count {
            encryptedPacket[i+nonceData.count+1] = cypher![i]
        }


        let packetData = Data(encryptedPacket)
        print("Sent Data is \(data)")

        udpSocket?.send(packetData, toHost: udpAddress, port: udpPort, withTimeout: -1, tag: 1)
        encryptionNonce += 1
    }


    /*
    * Sends a packet to the server, packet should already be encrypted.
    */
    private func sendPacket(data: Data, length: Int) throws {
         udpSocket?.send(data, toHost: udpAddress, port: UInt16(udpPort), withTimeout: -1, tag: 0)
    }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
          print("didSendDataWithTag = \(" ")\(tag)")
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
        print(imgData)
            if let bitmap = UIImage(data: imgData) {
                DispatchQueue.main.async {
                    self.liveImageView.image = bitmap
                }
            }
    }




}
