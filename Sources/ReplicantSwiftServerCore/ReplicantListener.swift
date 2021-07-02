//
//  ReplicantListener.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/29/18.
//

import Foundation
import Logging

import Transport
import ReplicantSwift
import SwiftQueue
import Flower

#if os(Linux)
import NetworkLinux
import TransmissionLinux
#else
import Network
import Transmission
#endif

import TransmissionTransport

class ReplicantListener: Transport.Listener
{
    var debugDescription: String = "[ReplicantTCPListener]"
    var newTransportConnectionHandler: ((Transport.Connection) -> Void)?
    var parameters: NWParameters
    var port: NWEndpoint.Port?
    var queue: DispatchQueue? = DispatchQueue(label: "Replicant Server Queue")
    var stateUpdateHandler: ((NWListener.State) -> Void)?
    let logger: Logger
    
    var newConnectionHandler: ((Transport.Connection) -> Void)?
    var config: ReplicantServerConfig
    #if os(Linux)
    var listener: TransmissionLinux.Listener    
    #else
    var listener: Transmission.Listener    
    #endif
    
    required init(replicantConfig: ReplicantServerConfig, serverConfig: ServerConfig, logger: Logger) throws
    {
        self.parameters = .tcp
        self.config = replicantConfig
        self.port = serverConfig.port
        self.logger = logger
        
        // Create the listener
        #if os(Linux)
        guard let listener = TransmissionLinux.Listener(port: Int(serverConfig.port.rawValue)) else
	{
            print("\n😮  Listener creation error  😮\n")
            throw ListenerError.initializationError
        }
        #else
        guard let listener = Transmission.Listener(port: Int(serverConfig.port.rawValue)) else
	{
            print("\n😮  Listener creation error  😮\n")
            throw ListenerError.initializationError
        }
        #endif

        self.listener = listener
    }

    #if os(Linux)    
    func replicantListenerNewConnectionHandler(newConnection: TransmissionLinux.Connection) {
        print("\nReplicant Listener new connection handler called.")
        guard var replicantConnection = makeReplicant(connection: newConnection)
        else
        {
            print("Unable to convert new connection to a Replicant connection.")
            return
        }
        
//        replicantConnection.stateUpdateHandler =
//        {
//            newState in
//
//            print("Received a state update on our Replicant connection: \(newState)")
//
//            switch newState
//            {
//            case .ready:
//                print("Replicant connection state update handler is in the READY state.")
//                if let connectionHandler = self.newTransportConnectionHandler
//                {
//                    connectionHandler(replicantConnection)
//                }
//            default:
//                return
//            }
//        }
        
        replicantConnection.start(queue: queue!)
        print("Replicant connection started!")
        
                if let connectionHandler = self.newTransportConnectionHandler
                {
                    connectionHandler(replicantConnection)
                }
        
    }
    #else
    func replicantListenerNewConnectionHandler(newConnection: Transmission.Connection) {
        print("\nReplicant Listener new connection handler called.")
        guard var replicantConnection = makeReplicant(connection: newConnection)
        else
        {
            print("Unable to convert new connection to a Replicant connection.")
            return
        }
        
        replicantConnection.stateUpdateHandler =
        {
            newState in
            
            print("Received a state update on our Replicant connection: \(newState)")
            
            switch newState
            {
            case .ready:
                print("Replicant connection state update handler is in the READY state.")
                if let connectionHandler = self.newTransportConnectionHandler
                {
                    connectionHandler(replicantConnection)
                }
            default:
                return
            }
        }
        
        replicantConnection.start(queue: queue!)
    }
    #endif

    #if os(Linux)
    func makeReplicant(connection: TransmissionLinux.Connection) -> Transport.Connection?
    {
        let transport = TransmissionToTransportConnection(connection)

        let replicantConnectionFactory = ReplicantServerConnectionFactory(
            connection: transport,
            replicantConfig: config,
            logger: logger)
        
        let newConnection = replicantConnectionFactory.connect()
        
        if newConnection == nil
        {
            print("\nReplicant connection factory returned a nil connection object.")
        }
        else
        {
            print("\nConnection object created with Replicant connection factory.")
        }
        
        return newConnection
    }
    #else
    func makeReplicant(connection: Transmission.Connection) -> Transport.Connection?
    {
        let replicantConnectionFactory = ReplicantServerConnectionFactory(
            connection: connection,
            replicantConfig: config,
            logger: logger)
        
        let newConnection = replicantConnectionFactory.connect()
        
        if newConnection == nil
        {
            print("\nReplicant connection factory returned a nil connection object.")
        }
        else
        {
            print("\nConnection object created with Replicant connection factory.")
        }
        
        return newConnection
    }
    #endif
    
    //MARK: Transport API Listener Protocol
    
    func start(queue: DispatchQueue)
    {
        queue.async
        {
            [self] in

            if let handler = self.stateUpdateHandler
            {
                handler(.ready)
            }

            while true
            {
                guard let newNetworkConnection = listener.accept() else {return}

                print("We have a new network connection.")
                print("\n newNetworkConnection: \(type(of: newNetworkConnection)) \n ")
                print("I seen't it.")
                newNetworkConnection.write(string: "start")
                let ipMessage = Message.IPAssignV4(IPv4Address("127.0.0.1")!)
                let ipMessageData = ipMessage.data
                newNetworkConnection.write(data: ipMessageData)
                newNetworkConnection.write(string: "\(ipMessageData)")
                print(ipMessageData)
                // Try to turn our network connection into a ReplicantServerConnection
                self.replicantListenerNewConnectionHandler(newConnection: newNetworkConnection)
            }
        }
    }
    
    func cancel()
    {
        // FIXME: Implement cancel() in Transmission
        // listener.cancel()
        
        if let stateUpdateHandler = stateUpdateHandler
        {
            stateUpdateHandler(NWListener.State.cancelled)
        }
    }
  
}

enum ListenerError: Error
{
    case invalidPort
    case initializationError
}
