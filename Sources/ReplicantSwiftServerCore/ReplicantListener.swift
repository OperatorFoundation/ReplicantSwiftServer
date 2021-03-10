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

#if os(Linux)
import TransmissionLinux
#else
import Transmission
#endif

class ReplicantListener: Listener
{
    var debugDescription: String = "[ReplicantTCPListener]"
    var newTransportConnectionHandler: ((Connection) -> Void)?
    var parameters: NWParameters
    var port: NWEndpoint.Port?
    var queue: DispatchQueue? = DispatchQueue(label: "Replicant Server Queue")
    var stateUpdateHandler: ((NWListener.State) -> Void)?
    let logger: Logger
    
    var newConnectionHandler: ((Connection) -> Void)?
    var config: ReplicantServerConfig
    var listener: Listener
    
    
    required init(replicantConfig: ReplicantServerConfig, serverConfig: ServerConfig, logger: Logger) throws
    {
        self.parameters = .tcp
        self.config = replicantConfig
        self.port = serverConfig.port
        self.logger = logger
        
        // Create the listener
        guard let listener = Listener(serverConfig.port) else
        {
            print("\n😮  Listener creation error: \(error)  😮\n")
            throw ListenerError.initializationError
        }

        self.listener = listener
    }
    
    func replicantListenerNewConnectionHandler(newConnection: Connection)
    {
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
    
    func makeReplicant(connection: Connection) -> Connection?
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
    
    //MARK: Transport API Listener Protocol
    
    func start(queue: DispatchQueue)
    {
        queue.async
        {
            if let handler = self.stateUpdateHandler
            {
                handler(.ready)
            }

            while true
            {
                let newNetworkConnection = listener.accept()

                print("We have a new network connection.")

                // Try to turn our network connection into a ReplicantServerConnection
                self.replicantListenerNewConnectionHandler(newConnection: newNetworkConnection)
            }
        }
    }
    
    func cancel()
    {
        listener.cancel()
        
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
