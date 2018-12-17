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

class RoutingController: NSObject
{
    let wireGuardServerIPString = ""
    let wireGuardServerPort: UInt16 = 51820
    var conduitCollection = ConduitCollection()
    var replicantEnabled = true
    
    func startListening(onPort portString: String, replicantEnabled: Bool)
    {
        guard let port = NWEndpoint.Port(rawValue: wireGuardServerPort)
            else
        {
            print("Unable to start listening, unable to resolve port.")
            return
        }
        
        self.replicantEnabled = replicantEnabled
        
        if replicantEnabled
        {
            guard let config = sampleReplicantConfig()
            else
            {
                print("\nUnable to start listening: failed to create a sample config.\n")
                return
            }
            
            do
            {
                let replicantListener = try ReplicantListener(config: config, on: port)
                replicantListener.stateUpdateHandler = debugListenerStateUpdateHandler
                replicantListener.newTransportConnectionHandler =
                {
                    [weak self] (plainConnection) in
                    
                    if let strongSelf = self
                    {
                        strongSelf.listenerConnectionHandler(newConnection: plainConnection, port: port)
                    }
                }
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
        guard let ipv4Address = IPv4Address(wireGuardServerIPString)
            else
        {
            print("\nUnable to resolve ipv4 address for WireGuard server.\n")
            return
        }
        
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        let maybeConnection = connectionFactory.connect(using: .udp)
        
        guard var wgConnection = maybeConnection
            else
        {
            print("Unable to create connection to the WireGuard server.")
            return
        }
        
        wgConnection.stateUpdateHandler = debugConnectionStateUpdateHandler
        
        let transferID = conduitCollection.addConduit(wireGuardConnection: wgConnection, transportConnection: newConnection)
        
        let transferQueue1 = DispatchQueue(label: "Transfer Queue 1")
        
        transferQueue1.async
        {
            self.transfer(from: newConnection, to: wgConnection, transferID: transferID)
        }
        
        let transferQueue2 = DispatchQueue(label: "Transfer Queue 2")
        
        transferQueue2.async
        {
            self.transfer(from: wgConnection, to: newConnection, transferID: transferID)
        }
    }
    
    func transfer(from receiveConnection: Connection, to sendConnection: Connection, transferID: Int)
    {
        receiveConnection.receive
        {
            (maybeReceiveData, maybeReceiveContext, receivedComplete, maybeReceiveError) in
            
            if let receiveError = maybeReceiveError
            {
                print("Received an error on receiveConnection.recieve: \(receiveError)")
                self.stopTransfer(for: transferID)
                return
            }
            
            if let receiveData = maybeReceiveData
            {
                sendConnection.send(content: receiveData,
                                    contentContext: .defaultMessage,
                                    isComplete: receivedComplete,
                                    completion: NWConnection.SendCompletion.contentProcessed(
                                        
                { (maybeSendError) in
                    
                    if let sendError = maybeSendError
                    {
                        print("\nReceived a send error: \(sendError)\n")
                        self.stopTransfer(for: transferID)
                        return
                    }
                    else
                    {
                        self.transfer(from: receiveConnection, to: sendConnection, transferID: transferID)
                    }
                }))
            }
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
        
        // Call Cancel on both connections
        conduit.wireGuardConnection.cancel()
        conduit.transportConnection.cancel()
        
        // Remove connections from ClientConnectionController dict.
        conduitCollection.removeConduit(with: clientID)
    }
    
    ///TODO: This is meant for development purposes only
    func sampleReplicantConfig() -> ReplicantConfig?
    {
        // Generate private key
        let tag = "org.operatorfoundation.replicant.server".data(using: .utf8)!
        
        let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                     .privateKeyUsage,
                                                     nil)!
        
        let privateKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tag
            /*kSecAttrAccessControl as String: access*/
        ]
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            /*kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,*/
            kSecPrivateKeyAttrs as String: privateKeyAttributes
        ]
        
        var error: Unmanaged<CFError>?
        guard let bobPrivate = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
            else
        {
            print("\nUnable to generate the client private key: \(error!.takeRetainedValue() as Error)\n")
            return nil
        }
        
        guard let bobPublic = SecKeyCopyPublicKey(bobPrivate)
            else
        {
            print("\nUnable to generate a public key from the provided private key.\n")
            return nil
        }
        
        // Encode key as data
        guard let bobPublicData = SecKeyCopyExternalRepresentation(bobPublic, &error) as Data?
            else
        {
            print("\nUnable to generate public key external representation: \(error!.takeRetainedValue() as Error)\n")
            return nil
        }
        
        guard let sampleSequence = SequenceModel(sequence: Data(string: "You say hello, and I say goodbye."), length: 256)
            else
        {
            return nil
        }
        
        return ReplicantConfig(serverPublicKey: bobPublicData, chunkSize: 4096, chunkTimeout: 60, addSequences: [sampleSequence], removeSequences: [sampleSequence])
    }
}
