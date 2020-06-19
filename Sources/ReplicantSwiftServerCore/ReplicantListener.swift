//
//  ReplicantListener.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/29/18.
//

import Foundation
import Network
import CryptoKit
import Transport
import Replicant
import ReplicantSwift
import SwiftQueue

class ReplicantListener: Listener
{
    var debugDescription: String = "[ReplicantTCPListener]"
    var newTransportConnectionHandler: ((Connection) -> Void)?
    var parameters: NWParameters
    var port: NWEndpoint.Port?
    var queue: DispatchQueue? = DispatchQueue(label: "Replicant Server Queue")
    var stateUpdateHandler: ((NWListener.State) -> Void)?
    
    var newConnectionHandler: ((Connection) -> Void)?
    var config: ReplicantServerConfig
    var listener: Listener
    var logQueue: Queue<String>
    
    required init(replicantConfig: ReplicantServerConfig, serverConfig: ServerConfig, logQueue: Queue<String>) throws
    {
        self.parameters = .tcp
        self.config = replicantConfig
        self.port = serverConfig.port
        self.logQueue = logQueue
        
        // Create the listener
        do
        {
            listener = try NWListener(using: .tcp, on: serverConfig.port)
        }
        catch (let error)
        {
            print("\n😮  Listener creation error: \(error)  😮\n")
            throw ListenerError.initializationError
        }
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
        let replicantConnectionFactory = ReplicantServerConnectionFactory(connection: connection, replicantConfig: config, logQueue: logQueue)
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
        // Start the listener
        listener.stateUpdateHandler =
        {
            (state) in
            
            print("Network listener stateUpdateHandler state: \(state)")
            
            // Call the Replicant stateUpdateHandler and pass along the network listener's state
            if let handler = self.stateUpdateHandler
            {
                handler(state)
            }
            
        }
        
        listener.newTransportConnectionHandler =
        {
            (newNetworkConnection) in
            
            print("We have a new network connection.")
            
            // Try to turn our network connection into a ReplicantServerConnection
            self.replicantListenerNewConnectionHandler(newConnection: newNetworkConnection)
            
        }
        
        listener.start(queue: queue)
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
