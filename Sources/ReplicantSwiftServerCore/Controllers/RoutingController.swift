//
//  RoutingController.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/30/18.
//

import Foundation
import Network
import Transport
import Replicant
import ReplicantSwift
import Flower

public class RoutingController: NSObject
{
    let consoleIO = ConsoleIO()
    let wireGuardServerIPString = "0.0.0.0"
    let wireGuardServerPort = NWEndpoint.Port(rawValue: 51820)
    let listenerQueue = DispatchQueue(label: "Listener")
    var conduitCollection = ConduitCollection()
    var replicantEnabled = true
    let tun = TunDevice(address: "10.0.0.1")
    var pool = AddressPool()
    let packetSize: Int = 2000 // FIXME - set this to a thoughtful value
    
    public func startListening(serverConfig: ServerConfig, replicantConfig: ReplicantServerConfig,  replicantEnabled: Bool)
    {
        ///FIXME: Default port?
        let port = wireGuardServerPort
        
        self.replicantEnabled = replicantEnabled
        
        if replicantEnabled
        {
            do
            {
                let replicantListener = try ReplicantListener(replicantConfig: replicantConfig, serverConfig: serverConfig)
                replicantListener.stateUpdateHandler = debugListenerStateUpdateHandler
                replicantListener.newTransportConnectionHandler =
                {
                    plainConnection in
                    
                    self.consoleIO.writeMessage("ConsoleIO Message: startListening called.")
                    print("Printing the port: \(String(describing: port))")
                    
                    self.listenerConnectionHandler(newConnection: plainConnection, port: serverConfig.port)
//
//                    if let strongSelf = self
//                    {
//                        strongSelf.consoleIO.writeMessage("ConsoleIO Message: startListening called.")
//                        print("Printing the port: \(String(describing: port))")
//
//                        strongSelf.listenerConnectionHandler(newConnection: plainConnection, port: serverConfig.port)
//                    }
                }
                
                replicantListener.start(queue: listenerQueue)
            }
            catch
            {
                print("\nUnable to create ReplicantListener\n")
            }
        }
    }
    
    func debugListenerStateUpdateHandler(newState: NWListener.State)
    {
        switch newState
        {
        case .ready:
            print("\nListening...\n")
        case .failed(let error):
            print("\nListener failed with error: \(error)\n")
        default:
            print("\nReceived unexpected state: \(newState)\n")
            break
        }
    }
    
    func debugConnectionStateUpdateHandler(newState: NWConnection.State)
    {
        switch newState
        {
        case .cancelled:
            print("\nWireGuard server connection canceled.")
        case .failed(let networkError):
            print("\nWireGuard server connection failed with error:  \(networkError)")
        case .preparing:
            print("\nPreparing connection to Wireguard server.")
        case .setup:
            print("\nWireGuard connection in setup phase.")
        case .waiting(let waitError):
            print("\n⏳\nWireguard connection waiting with error: \(waitError)")
        case .ready:
            print("\nWireGuard Connection is Ready")
        }
    }

    func listenerConnectionHandler(newConnection: Connection, port: NWEndpoint.Port)
    {
        // FIXME - support IPv6
        guard let address = pool.allocate() else
        {
            return
        }
        
        guard let v4 = IPv4Address(address) else
        {
            return
        }
        
        let transferID = conduitCollection.addConduit(address: address, transportConnection: newConnection)

        // FIXME - support IPv6
        newConnection.writeMessage(message: Message.IPAssignV4(v4))
        {
            (maybeError) in
            
            guard maybeError == nil else
            {
                print("Error sending IP assignment")
                return
            }
            
            let transferQueue1 = DispatchQueue(label: "Transfer Queue 1")
            
            transferQueue1.async
                {
                    self.transfer(from: newConnection, toAddress: address, transferID: transferID)
            }
            
            let transferQueue2 = DispatchQueue(label: "Transfer Queue 2")
            
            transferQueue2.async
                {
                    self.transfer(fromAddress: address, to: newConnection, transferID: transferID)
            }
        }
    }
    
    func transfer(from receiveConnection: Connection, toAddress sendAddress: String, transferID: Int)
    {
        receiveConnection.readMessages
        {
            (message) in
            
            guard let realtun = self.tun else
            {
                print("No TUN device")
                self.stopTransfer(for: transferID)
                return
            }
            
            switch message{
                case .IPDataV4(let payload):
                    realtun.writeV4(payload)
                case .IPDataV6(let payload):
                    realtun.writeV6(payload)
                default:
                    print("Unsupported message type")
                    self.stopTransfer(for: transferID)
                    return
            }
        }
    }

    func transfer(fromAddress receiveAddress: String, to sendConnection: Connection, transferID: Int)
    {
        guard let realtun = self.tun else
        {
            print("No TUN device")
            self.stopTransfer(for: transferID)
            return
        }
        
        guard let (packet, protocolNumber) = realtun.read(packetSize: packetSize) else
        {
            print("No packet from TUN")
            self.stopTransfer(for: transferID)
            return
        }
        
        switch protocolNumber
        {
            case 4:
                let message = Message.IPDataV4(packet)
                
                sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
                    (maybeSendError) in
                    
                    if let sendError = maybeSendError
                    {
                        print("\nReceived a send error: \(sendError)\n")
                        self.stopTransfer(for: transferID)
                        return
                    }
                    else
                    {
                        self.transfer(fromAddress: receiveAddress, to: sendConnection, transferID: transferID)
                    }
                }))
            case 6:
                let message = Message.IPDataV6(packet)
                
                sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
                    (maybeSendError) in
                    
                    if let sendError = maybeSendError
                    {
                        print("\nReceived a send error: \(sendError)\n")
                        self.stopTransfer(for: transferID)
                        return
                    }
                    else
                    {
                        self.transfer(fromAddress: receiveAddress, to: sendConnection, transferID: transferID)
                    }
                }))
            default:
                print("Unsupported protocol number")
                self.stopTransfer(for: transferID)
                return
        }
    }
    
    func stopTransfer(for clientID: Int)
    {
        guard let conduit = conduitCollection.getConduit(with: clientID)
            else
        {
            print("No transfer to stop, no conduit found for clientID: \(clientID)")
            return
        }
        
        // FIXME - Figure out how to support both IPv4 and IPv6 tunnels
        conduit.transportConnection.writeMessage(message: Message.IPCloseV4()) {
            (maybeError) in
            
            self.pool.deallocate(address: conduit.address)
            conduit.transportConnection.cancel()
        }
        
        // Remove connections from ClientConnectionController dict.
        conduitCollection.removeConduit(with: clientID)
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
