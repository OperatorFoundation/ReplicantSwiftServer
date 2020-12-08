//
//  RoutingController.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/30/18.
//

import Foundation
import Logging

import InternetProtocols
import Transport
import ReplicantSwift
import Flower
import Tun

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

public class RoutingController: NSObject
{
    let logger: Logger
    let consoleIO = ConsoleIO()
    let listenerQueue = DispatchQueue(label: "Listener")
    let tun = TunDevice(address: "10.0.0.1")
    let packetSize: Int = 2000 // FIXME - set this to a thoughtful value
    
    var conduitCollection = ConduitCollection()
    var replicantEnabled = true
    var pool = AddressPool()
    
    public init(logger: Logger)
    {
        self.logger = logger
    }
    
    public func startListening(serverConfig: ServerConfig, replicantConfig: ReplicantServerConfig,  replicantEnabled: Bool)
    {
        let port = serverConfig.port
        print("Printing the port: \(String(describing: port))")

        self.replicantEnabled = replicantEnabled
        
        if replicantEnabled
        {
            do
            {
                let replicantListener = try ReplicantListener(replicantConfig: replicantConfig, serverConfig: serverConfig, logger: logger)
                replicantListener.stateUpdateHandler = debugListenerStateUpdateHandler
                replicantListener.newTransportConnectionHandler =
                {
                    (replicantConnection) in
                    
                    self.consoleIO.writeMessage("New Replicant Connection!")
                    self.process(newReplicantConnection: replicantConnection, port: serverConfig.port)
                }
                
                replicantListener.start(queue: listenerQueue)
            }
            catch
            {
                print("\nUnable to create ReplicantListener\n")
            }
        }
        
        let transferQueue2 = DispatchQueue(label: "Transfer Queue 2")
        
        transferQueue2.async
        {
            self.transferFromTUN()
        }
    }
    
    func debugListenerStateUpdateHandler(newState: NWListener.State)
    {
        switch newState
        {
            case .ready:
                print("\nListening...\n")
            case .failed(let error):
                print("\nListener failed with error: \(error.localizedDescription)\n")
            case .waiting(let error):
                print("\nListener waiting with error: \(error)\n")
            default:
                print("\nReceived unexpected state: \(newState)\n")
        }
    }
    
    func debugConnectionStateUpdateHandler(newState: NWConnection.State)
    {
        switch newState
        {
            case .cancelled:
                print("Server connection canceled.\n")
            case .failed(let networkError):
                print("Server connection failed with error:  \(networkError)\n")
            case .preparing:
                print("Preparing connection to server.\n")
            case .setup:
                print("Connection in setup phase.\n")
            case .waiting(let waitError):
                print("⏳ Connection waiting with error: \(waitError)\n")
            case .ready:
                print("Connection is Ready\n")
            default:
                print("Unexpected state: \(newState)")
        }
    }

    func process(newReplicantConnection: Connection, port: NWEndpoint.Port)
    {
        print("Routing controller listener connection handler called.")

        // FIXME - support IPv6
        guard let address = pool.allocate() else
        {
            print("Error getting connection address in connection handler.")
            return
        }
        
        guard let v4 = IPv4Address(address) else
        {
            print("Unable to get IPV4 address in connection handler.")
            return
        }
        
        conduitCollection.addConduit(address: address, transportConnection: newReplicantConnection)

        // FIXME - support IPv6
        let ipv4AssignMessage = Message.IPAssignV4(v4)
        newReplicantConnection.writeMessage(message: ipv4AssignMessage)
        {
            (maybeError) in
            
            print("\n🌷 Listener connection handler sent a message.\(ipv4AssignMessage) 🌷")
            guard maybeError == nil else
            {
                print("Error sending IP assignment")
                return
            }
            
            let transferQueue1 = DispatchQueue(label: "Transfer Queue 1")
            
            transferQueue1.async
            {
                self.transfer(from: newReplicantConnection, toAddress: address)
            }
        }
    }
    
    func transfer(from receiveConnection: Connection, toAddress sendAddress: String)
    {
        receiveConnection.readMessages
        {
            (message) in
            
            print("🌷 Received a message: \(message.description) 🌷")
            
            guard let realtun = self.tun else
            {
                print("No TUN device")
                return
            }
            
            switch message
            {
                case .IPDataV4(let payload):
                    print("\nReading an ipv4 message")
                    let now = Date()
                    let packet = Packet(rawBytes: payload, timestamp: now)
                    
                    guard let sourceAddress = IPv4Address(sendAddress) else
                    {
                        return
                    }
                    
                    guard packet.sourceIPAddress == sourceAddress else
                    {
                        return
                    }
                    
                    realtun.writeV4(payload)
                case .IPDataV6(let payload):
                    print("\nReading an IPV6 message.")
                    realtun.writeV6(payload)
                default:
                    print("\nUnsupported message type")
                    return
            }
        }
    }

    func transferFromTUN()
    {
        guard let realtun = self.tun else
        {
            print("No TUN device")
            return
        }
        
        guard let (payload, protocolNumber) = realtun.read(packetSize: packetSize) else
        {
            print("No packet from TUN")
            return
        }
        
        switch Int32(protocolNumber)
        {
            case AF_INET:
                let packet = Packet(rawBytes: payload, timestamp: Date())
                let destAddress = packet.destinationIPAddress.debugDescription
                
                guard let conduit = conduitCollection.getConduit(with: destAddress) else
                {
                    return
                }
                
                let sendConnection = conduit.transportConnection
                
                print("🌷 Transfer from TUN payload: \(payload) 🌷")
                let message = Message.IPDataV4(payload)
                print("🌷 Transfer from TUN created a message: \(message.description) 🌷")
                
                sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
                    (maybeSendError) in
                    
                    if let sendError = maybeSendError
                    {
                        print("\nReceived a send error: \(sendError)\n")
                        return
                    }
                    else
                    {
                        self.transferFromTUN()
                    }
                }))
            case AF_INET6:
                let packet = Packet(rawBytes: payload, timestamp: Date())
                let destAddress = packet.destinationIPAddress.debugDescription
                
                guard let conduit = conduitCollection.getConduit(with: destAddress) else
                {
                    return
                }
                
                let sendConnection = conduit.transportConnection
                
                let message = Message.IPDataV6(payload)
                
                sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
                    (maybeSendError) in
                    
                    if let sendError = maybeSendError
                    {
                        print("\nReceived a send error: \(sendError)\n")
                        return
                    }
                    else
                    {
                        self.transferFromTUN()
                    }
                }))
            default:
                print("Unsupported protocol number")
                return
        }
    }
    
    ///TODO: This is meant for development purposes only
//    func sampleReplicantConfig() -> ReplicantConfig?
//    {
//        // Generate private key
//        let tag = "org.operatorfoundation.replicant.server".data(using: .utf8)!
//
//        let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
//                                                     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
//                                                     .privateKeyUsage,
//                                                     nil)!
//
//        let privateKeyAttributes: [String: Any] = [
//            kSecAttrIsPermanent as String: true,
//            kSecAttrApplicationTag as String: tag
//            /*kSecAttrAccessControl as String: access*/
//        ]
//
//        let attributes: [String: Any] = [
//            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
//            kSecAttrKeySizeInBits as String: 256,
//            /*kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,*/
//            kSecPrivateKeyAttrs as String: privateKeyAttributes
//        ]
//
//        var error: Unmanaged<CFError>?
//        guard let bobPrivate = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
//            else
//        {
//            print("\nUnable to generate the client private key: \(error!.takeRetainedValue() as Error)\n")
//            return nil
//        }
//
//        guard let bobPublic = SecKeyCopyPublicKey(bobPrivate)
//            else
//        {
//            print("\nUnable to generate a public key from the provided private key.\n")
//            return nil
//        }
//
//        // Encode key as data
//        guard let bobPublicData = SecKeyCopyExternalRepresentation(bobPublic, &error) as Data?
//            else
//        {
//            print("\nUnable to generate public key external representation: \(error!.takeRetainedValue() as Error)\n")
//            return nil
//        }
//
//        guard let sampleSequence = SequenceModel(sequence: Data(string: "You say hello, and I say goodbye."), length: 256)
//            else
//        {
//            return nil
//        }
//
//        return ReplicantConfig(serverPublicKey: bobPublicData, chunkSize: 4096, chunkTimeout: 60, addSequences: [sampleSequence], removeSequences: [sampleSequence])
//    }
}
