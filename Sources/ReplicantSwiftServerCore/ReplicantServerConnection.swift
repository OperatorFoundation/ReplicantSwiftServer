//
//  ReplicantServerConnection.swift
//  Replicant
//
//  Created by Adelita Schule on 12/3/18.
//  MIT License
//
//  Copyright (c) 2020 Operator Foundation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Dispatch
import Logging

import Flower
import Transport
import Transmission
import ReplicantSwift
import Net

open class ReplicantServerConnection: Transport.Connection
{
    public let payloadLengthOverhead = 2
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var replicantConfig: ReplicantServerConfig
    public var replicantServerModel: ReplicantServerModel
    
    let log: Logger
    
    // FIXME: Unencrypted chunk size for non-polish instances
    var unencryptedChunkSize: UInt16 = 400
    var sendTimer: Timer?
    var bufferLock = DispatchGroup()
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var sendBufferQueue = DispatchQueue(label: "SendBuffer Queue")
    var sendMessageQueue = DispatchQueue(label: "ReplicantServerConnection.sendMessageQueue")
    var network: Transmission.Connection
    var sendBuffer = Data()
    var decryptedReceiveBuffer = Data()
    var wasReady = false
    
    public init?(connection: Transmission.Connection,
                 parameters: NWParameters,
                 replicantConfig: ReplicantServerConfig,
                 logger: Logger)
    {
        guard let newReplicant = ReplicantServerModel(withConfig: replicantConfig, logger: logger)
        else
        {
            logger.error("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            return nil
        }
        
        self.log = logger
        self.network = connection
        self.replicantConfig = replicantConfig
        self.replicantServerModel = newReplicant
        if let polish = replicantServerModel.polish
        {
            self.unencryptedChunkSize =
            polish.chunkSize - UInt16(payloadLengthOverhead)
        }
    }
    
    public func start(queue: DispatchQueue)
    {
        self.introductions
        {
            (maybeIntroError) in
            
            guard maybeIntroError == nil
                else
            {
                self.log.error("\nError attempting to meet the server during Replicant Connection Init: \(maybeIntroError!)\n")
                if let introError = maybeIntroError as? NWError
                {
                    self.updateHandler(NWConnection.State.failed(introError))
                }
                else
                {
                    self.updateHandler(NWConnection.State.cancelled)
                }
                
                return
            }
            
            self.log.debug("\n New Replicant connection is ready. 🎉 \n")
            
            self.updateHandler(NWConnection.State.ready)
        }
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        if let polish = replicantServerModel.polish
        {
            // Lock so that the timer cannot fire and change the buffer.
            bufferLock.enter()
            
            guard let someData = content else
            {
                log.error("Received a send command with no content.")
                switch completion
                {
                case .contentProcessed(let handler):
                    handler(nil)
                    bufferLock.leave()
                    return
                default:
                    bufferLock.leave()
                    return
                }
            }
            
            self.sendBuffer.append(someData)
            
            sendBufferChunks(polishServer: polish, contentContext: contentContext, isComplete: isComplete, completion: completion)
        }
        else
        {
            log.debug("Replicant send is calling network send")
            log.debug("\n network:\(type(of: network))\n ")
            guard let data = content else {
                self.log.error("ReplicantServerConnection.swift: send data was nil")
            }
            guard network.write(data: data) else {
                log.error("ReplicantServerConnection.swift: network write failed")
            }
            switch completion {
                case .contentProcessed(let callback):
                    callback(NWError.posix(POSIXErrorCode.ECONNREFUSED))
                default: return
            }
            log.debug("Replicant send is finished calling network send")
        }
    }
    
    func sendBufferChunks(polishServer: PolishServer, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        // Only encrypt and send over network when chunk size is available, leftovers to the buffer
        guard self.sendBuffer.count >= (polishServer.chunkSize)
            else
        {
            log.error("Received a send command with content less than chunk size.")
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(nil)
                    bufferLock.leave()
                    return
                default:
                    bufferLock.leave()
                    return
            }
        }
        
        let payloadData = self.sendBuffer[0 ..< polishServer.chunkSize]
        let payloadSize = polishServer.chunkSize
        let dataChunk = payloadSize.data + payloadData
        guard let polishServerConnection = polishServer.newConnection(connection: self.network)
        else
        {
            log.error("Received a send command but we could not derive the symmetric key.")
            switch completion
            {
                case .contentProcessed(let handler):
                    let errorCode: Int32 = 126
                    handler(NWError.posix(POSIXErrorCode(rawValue: errorCode)!))
                    
                    bufferLock.leave()
                    return
                default:
                    bufferLock.leave()
                    return
            }
        }
        
        let maybeEncryptedData = polishServerConnection.polish(inputData: dataChunk)
        
        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[polishServer.chunkSize...]
        
        // Turn off the timer
        if sendTimer != nil
        {
            self.sendTimer!.invalidate()
            self.sendTimer = nil
        }
        
        // Keep calling network.write if the leftover data is at least chunk size
        guard let encryptedData = maybeEncryptedData else {
            // FIXME: is this all we need to do?
            self.bufferLock.leave()
            return
        }
        
        guard self.network.write(data: encryptedData) else {
            self.log.error("ReplicantServerConnection.swift: Received an error on network write")
            self.sendTimer!.invalidate()
            self.sendTimer = nil
            
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(NWError.posix(POSIXErrorCode.ECONNREFUSED))
                    self.bufferLock.leave()
                    return
                default:
                    self.bufferLock.leave()
                    return
            }
            return
        }
        
        if self.sendBuffer.count >= (polishServer.chunkSize)
        {
            // Play it again Sam
            self.sendBufferChunks(polishServer: polishServer, contentContext: contentContext, isComplete: isComplete, completion: completion)
        }
        else
        {
            // Start the timer
            if self.sendBuffer.count > 0
            {
                
                // FIXME: Different timer for Linux as #selector requires objC
                
            }
            
            switch completion
            {
                // FIXME: There might be data in the buffer
                case .contentProcessed(let handler):
                    handler(nil)
                    self.bufferLock.leave()
                    return
                default:
                    self.bufferLock.leave()
                    return
            }
        }
    }

    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        if let polishServerConnection = replicantServerModel.polish
        {
            bufferLock.enter()
            
            // Check to see if we have min length data in decrypted buffer before calling network receive. Skip the call if we do.
            if decryptedReceiveBuffer.count >= minimumIncompleteLength
            {
                // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
                let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
                
                // Return the requested amount
                let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]
                
                // Remove what was delivered from the buffer
                self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
                
                completion(returnData, nil, false, nil)
                bufferLock.leave()
                return
            }
            else
            {
                guard let data = network.read(size: Int(polishServerConnection.chunkSize)) else {
                    self.log.error("ReplicantServerConnection.swift: failed on network read")
                    completion(nil, nil, true, NWError.posix(POSIXErrorCode.ECONNREFUSED))
                    self.bufferLock.leave()
                    return
                }
                
                // let maybeReturnData = 
                self.handleReceivedData(polish: polishServerConnection, minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, encryptedData: data)
                
                completion(data, nil, false, nil)
                self.bufferLock.leave()
                return
            }
        }
        else
        {
            guard let data = network.read(size: minimumIncompleteLength) else {
                self.log.error("ReplicantServerConnection.swift: failed on second network read")
                completion(nil, nil, true, NWError.posix(POSIXErrorCode.ECONNREFUSED))
                self.bufferLock.leave()
                return
            }
            completion(data, nil, false, nil)
            self.bufferLock.leave()
            return
        }
    }

    public func cancel()
    {
        // FIXME: need a proper way to cancel network connections
        // network.cancel()
        
        if let stateUpdate = self.stateUpdateHandler
        {
            stateUpdate(NWConnection.State.cancelled)
        }
        
        if let viabilityUpdate = self.viabilityUpdateHandler
        {
            viabilityUpdate(false)
        }
    }
    /// This takes an optional data and adds it to the buffer before acting on min/max lengths
    func handleReceivedData(polish: PolishServer, minimumIncompleteLength: Int, maximumLength: Int, encryptedData: Data) -> Data?
    {
        // Try to decrypt the entire contents of the encrypted buffer
        guard let polishServerConnection = polish.newConnection(connection: self.network)
        else
        {
            self.log.error("Unable to decrypt received data: Failed to create a polish connection")
             return nil
        }
        
        guard let decryptedData = polishServerConnection.unpolish(polishedData: encryptedData)
            else
        {
            self.log.error("Unable to decrypt encrypted receive buffer")
            return nil
        }
        
        // Add decrypted data to the decrypted buffer
        self.decryptedReceiveBuffer.append(decryptedData)
        
        // Check to see if the decrypted buffer meets min/max parameters
        guard decryptedReceiveBuffer.count >= minimumIncompleteLength
            else
        {
            // Not enough data return nothing
            return nil
        }
        
        // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
        let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
        
        // Return the requested amount
        let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]
        
        // Remove what was delivered from the buffer
        self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
        
        return returnData
    }
    
    func voightKampffTest(completion: @escaping (Error?) -> Void)
    {
        // Tone Burst
        if var toneBurst = self.replicantServerModel.toneBurst
        {
            toneBurst.play(connection: self.network)
            {
                maybeError in
                
                guard maybeError == nil else
                {
                    self.log.error("ToneBurst failed: \(maybeError!)")
                    completion(nil)
                    return
                }
                
                completion(maybeError)
            }
        }
        else
        {
            completion(nil)
        }
    }
    
    func introductions(completion: @escaping (Error?) -> Void)
    {
        voightKampffTest
        {
            (maybeVKError) in
            
            guard maybeVKError == nil
                else
            {
                self.stateUpdateHandler?(NWConnection.State.cancelled)
                completion(maybeVKError)
                return
            }
            
            if let polishServer = self.replicantServerModel.polish
            {
                guard var polishConnection = polishServer.newConnection(connection: self.network)
                    else
                {
                    completion(ReplicantError.invalidServerHandshake)
                    return
                }
                
                polishConnection.handshake(connection: self.network)
                {
                    (maybeHandshakeError) in
                    
                    if let handshakeError = maybeHandshakeError
                    {
                        self.stateUpdateHandler?(NWConnection.State.cancelled)
                        completion(handshakeError)
                        return
                    }
                    else
                    {
                        self.stateUpdateHandler?(NWConnection.State.ready)
                        completion(nil)
                    }
                }
            }
            else
            {
                completion(nil)
            }
        }
    }
    
    func chunkTimeout()
    {
        // Lock so that send isn't called while we're working
        bufferLock.enter()
        sendTimer = nil
        
        // Double check the buffer to be sure that there is still data in there.
        log.debug("\n⏰  Chunk Timeout Reached\n  ⏰")
        
        let payloadSize = sendBuffer.count

        if let polish = replicantServerModel.polish
        {
            guard let polishConnection = polish.newConnection(connection: network)
            else
            {
                log.error("Attempted to polish but failed to create a PolishConnection")
                bufferLock.leave()
                return
            }
            
            guard payloadSize > 0, payloadSize < polish.chunkSize else
            {
                bufferLock.leave()
                return
            }
                
            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding
            let maybeEncryptedData = polishConnection.polish(inputData: dataChunk)
            
            // Buffer should only contain unsent data
            self.sendBuffer = Data()
            
            // Keep calling network.write if the leftover data is at least chunk size
            guard let encryptedData = maybeEncryptedData else {
                self.log.error("ReplicantServerConnection.swift: could not unwrap encrypted data")
                self.bufferLock.leave()
                return
            }
            
            guard self.network.write(data: encryptedData) else {
                self.log.error("ReplicantServerConnection.swift: failed network write")
                self.bufferLock.leave()
                return
            }
            self.bufferLock.leave()
            return
            
        }
        else /// Replicant without polish
        {
            guard payloadSize > 0
                else
            {
                bufferLock.leave()
                return
            }
                
            // FIXME: padding and unencrypted chunk size for non-polish
            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding
            
            // Buffer should only contain unsent data
            self.sendBuffer = Data()
            
            // Keep calling network.write if the leftover data is at least chunk size
            guard self.network.write(data: dataChunk) else {
                self.log.error("ReplicantServerConnection.swift: Received an error on Send")
                
                self.bufferLock.leave()
                return
            }
            
            self.bufferLock.leave()
            return
        }
    }
    
    func updateHandler(_ state: NWConnection.State) {
        if let handler = self.stateUpdateHandler {
            handler(state)
        }
    }
}
