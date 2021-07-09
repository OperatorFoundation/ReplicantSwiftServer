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
import Routing

import NetworkLinux

#if os(Linux)
import TransmissionLinux
#else
import Transmission
#endif

import TransmissionTransport

public class RoutingController
{
    let logger: Logger
    let consoleIO = ConsoleIO()
    let listenerQueue = DispatchQueue(label: "Listener")
    var tun: TunDevice?
    let packetSize: Int = 2000 // FIXME - set this to a thoughtful value
    
    var conduitCollection = ConduitCollection()
    var replicantEnabled = true
    var pool = AddressPool()
    
    public required init?(logger: Logger)
    {
        self.logger = logger
    }
    
    public func startListening(serverConfig: ServerConfig, replicantConfig: ReplicantServerConfig,  replicantEnabled: Bool)
    {
        print("RoutingController.startListening")
        var packetCount = 0
        let reader =
        {
            (data: Data) in

            packetCount += 1
            print("packet count: \(packetCount)")
            print("Number of bytes: \(data.count)")

            let packet = Packet(rawBytes: data, timestamp: Date())

            guard let ipv4 = packet.ipv4 else
            {
                print("no ipv4")
                return
            }

            let destAddress = ipv4.destinationAddress.debugDescription

            guard let conduit = self.conduitCollection.getConduit(with: destAddress)
            else { return }

            let sendConnection = conduit.transportConnection

            // FIXME: May not be IPV4
            print("🌷 Transfer from TUN payload: \(data) 🌷")
            let message = Message.IPDataV4(data)
            print("🌷 Transfer from TUN created a message: \(message.description) 🌷")

            sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (maybeSendError) in

                    if let sendError = maybeSendError
                    {
                        print("\nReceived a send error: \(sendError)\n")
                        return
                    }
                })
            )
        }

        guard let tunDevice = TunDevice(address: "10.0.0.1", reader: reader)
        else
        {
            print("🚨 Failed to create tun device. 🚨")
            //return nil
            return
        }

        self.tun = tunDevice

        //setup routing (nat, ip forwarding, and mtu)
        // FIXME - server config should include an interface name to listen for connections on, for now it's static...
        let internetInterface: String = "enp0s5"
        print("⚠️ Setting internet interface to static value: \(internetInterface)! Update code to set value from config file. ⚠️")

        guard let tunName = tunDevice.maybeName else { return }
        setMTU(interface: tunName, mtu: 1380)
        //setAddressV6(interfaceName: tunName, addressString: tunAv6, subnetPrefix: 64)

        setIPv4Forwarding(setTo: true)
        //setIPv6Forwarding(setTo: true)

        print("[S] Deleting all ipv4 NAT entries for \(internetInterface)")
        var result4 = false
        while !result4
        {
            result4 = deleteServerNAT(serverPublicInterface: internetInterface)
        }

        //        print("[S] Deleting all ipv6 NAT entries for \(internetInterface)")
        //        var result6 = false
        //        while !result6
        //        {
        //            result6 = deleteServerNATv6(serverPublicInterface: internetInterface)
        //        }

        configServerNAT(serverPublicInterface: internetInterface)
        print("[S] Current ipv4 NAT: \n\n\(getNAT())\n\n")

        //        configServerNATv6(serverPublicInterface: internetInterface)
        //        print("[S] Current ipv6 NAT: \n\n\(getNATv6())\n\n")

        let port = serverConfig.port
        print("\n! Listening on port \(port)")

        self.replicantEnabled = replicantEnabled
        
        if replicantEnabled
        {
            print("Replicant listener")
            do
            {
                let replicantListener = try ReplicantListener(replicantConfig: replicantConfig, serverConfig: serverConfig, logger: logger)
                replicantListener.stateUpdateHandler = debugListenerStateUpdateHandler
                replicantListener.newTransportConnectionHandler =
                {
                    (replicantConnection) in

                    print("\nNew Replicant connection rececived.")
                    self.consoleIO.writeMessage("New Replicant Connection!")
                    self.process(newReplicantConnection: replicantConnection, port: serverConfig.port)
                }
                
                replicantListener.start(queue: listenerQueue)
                print("! Replicant listener started and listening")
            }
            catch
            {
                print("\nUnable to create ReplicantListener\n")
            }
        }
        else
        {
            print("! Plain listener")
            do
            {
                #if os(Linux)
                guard let listener = TransmissionLinux.Listener(port: Int(serverConfig.port.rawValue)) else {return}
                #else
                guard let listener = Transmission.Listener(port: Int(serverConfig.port.rawValue)) else {return}
                #endif
                print("started listener")

                while true
                {
                  guard let connection = listener.accept() else {return}
                  print("\nNew plain connection rececived.")
                  self.consoleIO.writeMessage("New plain Connection!")
                  let transport = TransmissionToTransportConnection(connection)
                  self.process(newReplicantConnection: transport, port: serverConfig.port)
                }
            }
            catch
            {
                print("\nUnable to create ReplicantListener\n")
            }
        }
        
        //        let transferQueue2 = DispatchQueue(label: "Transfer Queue 2")
        //
        //        transferQueue2.async
        //        {
        //            self.transferFromTUN()
        //        }

      print("End RoutingController.startListening")
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
        }
    }

    func process(newReplicantConnection: Transport.Connection, port: NWEndpoint.Port)
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

        print("conduit added successfully")
        
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
        print("WriteMessage called!")
    }
    
    func transfer(from receiveConnection: Transport.Connection, toAddress sendAddress: String)
    {
        receiveConnection.readMessages
        {
            (message) in
            
            print("🌷 Received a message: \(message.description) 🌷")
            
            switch message
            {
                case .IPDataV4(let payload):
                    print("\nReading an ipv4 message")
                    let now = Date()
                    let packet = Packet(rawBytes: payload, timestamp: now)
                    
                    guard let sourceAddress = IPv4Address(sendAddress) else
                    {
                        print("sourceAddress is nil")
                        return
                    }
                    
                    guard let ipv4 = packet.ipv4
                    else {
                        print("Packet was not IPV4")
                        return
                    }
                    
                    guard ipv4.sourceAddress == sourceAddress.rawValue else
                    {
                        print("sourceAddress rawValue is nil")
                        return
                    }

                    if let ourTun = self.tun{

                        let bytesWritten = ourTun.writeBytes(payload)
                        print("tun device wrote \(bytesWritten) bytes.")
                    } else {
                        print("no tun device")
                        return
                    }
                case .IPDataV6(let payload):
                    print("\nReading an IPV6 message.")
                    if let ourTun = self.tun {
                        let bytesWritten = ourTun.writeBytes(payload)
                        print("tun device wrote \(bytesWritten) bytes.")
                    }
                default:
                    print("\nUnsupported message type")
                    return
            }
        }
    }

    //    func transferFromTUN(data: Data)
    //    {
    ////        guard let payload = self.tun.read(packetSize: packetSize) else
    ////        {
    ////            print("No packet from TUN")
    ////            return
    ////        }
    //
    //        let packet = Packet(rawBytes: data, timestamp: Date())
    //
    //        guard let ipv4 = packet.ipv4
    //        else { return }
    //
    //        let destAddress = ipv4.destinationAddress.debugDescription
    //
    //        guard let conduit = conduitCollection.getConduit(with: destAddress)
    //        else { return }
    //
    //        let sendConnection = conduit.transportConnection
    //
    //        // FIXME: May not be IPV4
    //        print("🌷 Transfer from TUN payload: \(data) 🌷")
    //        let message = Message.IPDataV4(data)
    //        print("🌷 Transfer from TUN created a message: \(message.description) 🌷")
    //
    //        sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
    //            (maybeSendError) in
    //
    //            if let sendError = maybeSendError
    //            {
    //                print("\nReceived a send error: \(sendError)\n")
    //                return
    //            }
    ////            else
    ////            {
    ////                self.transferFromTUN()
    ////            }
    //        }
    //
    //
    //
    //        )
    //
    //        )
    //
    ////        switch Int32(protocolNumber)
    ////        {
    ////            case AF_INET:
    ////                let packet = Packet(rawBytes: payload, timestamp: Date())
    ////                let destAddress = packet.destinationIPAddress.debugDescription
    ////
    ////                guard let conduit = conduitCollection.getConduit(with: destAddress) else
    ////                {
    ////                    return
    ////                }
    ////
    ////                let sendConnection = conduit.transportConnection
    ////
    ////                print("🌷 Transfer from TUN payload: \(payload) 🌷")
    ////                let message = Message.IPDataV4(payload)
    ////                print("🌷 Transfer from TUN created a message: \(message.description) 🌷")
    ////
    ////                sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
    ////                    (maybeSendError) in
    ////
    ////                    if let sendError = maybeSendError
    ////                    {
    ////                        print("\nReceived a send error: \(sendError)\n")
    ////                        return
    ////                    }
    ////                    else
    ////                    {
    ////                        self.transferFromTUN()
    ////                    }
    ////                }))
    ////            case AF_INET6:
    ////                let packet = Packet(rawBytes: payload, timestamp: Date())
    ////                let destAddress = packet.destinationIPAddress.debugDescription
    ////
    ////                guard let conduit = conduitCollection.getConduit(with: destAddress) else
    ////                {
    ////                    return
    ////                }
    ////
    ////                let sendConnection = conduit.transportConnection
    ////
    ////                let message = Message.IPDataV6(payload)
    ////
    ////                sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
    ////                    (maybeSendError) in
    ////
    ////                    if let sendError = maybeSendError
    ////                    {
    ////                        print("\nReceived a send error: \(sendError)\n")
    ////                        return
    ////                    }
    ////                    else
    ////                    {
    ////                        self.transferFromTUN()
    ////                    }
    ////                }))
    ////            default:
    ////                print("Unsupported protocol number")
    ////                return
    ////        }
    //    }
    
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
