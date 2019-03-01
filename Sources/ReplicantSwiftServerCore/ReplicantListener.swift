//
//  ReplicantListener.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/29/18.
//

import Foundation
import Network
import Transport
import Replicant
import ReplicantSwift

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
    
    required init(replicantConfig: ReplicantServerConfig, serverConfig: ServerConfig) throws
    {
        self.parameters = .tcp
        self.config = replicantConfig
        self.port = serverConfig.port
        
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
            
            print("Received a state update on our replicant connection: \(newState)")
            
            switch newState
            {
            case .ready:
                self.newTransportConnectionHandler?(replicantConnection)
            default:
                print("Received a state update other than ready on our replicant connection: \(newState)")
            }
        }
        
        newConnection.start(queue: queue!)
    }
    
    func makeReplicant(connection: Connection) -> Connection?
    {
        let replicantConnectionFactory = ReplicantServerConnectionFactory(connection: connection, replicantConfig: config)
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
        print("\nReplicant Listener start called.")
        // Start the listener
        listener.stateUpdateHandler = stateUpdateHandler
        listener.newTransportConnectionHandler = replicantListenerNewConnectionHandler
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
