//
//  ReplicantListener.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/29/18.
//

import Foundation
import Logging

import ReplicantSwift
import SwiftQueue
import Flower
import Net
import Transmission
import TransmissionTransport

class ReplicantListener: Transmission.Listener
{
    var debugDescription: String = "[ReplicantTCPListener]"
    var newTransportConnectionHandler: ((Transmission.Connection) -> Void)?
    var parameters: NWParameters
    var port: Int
    var queue: DispatchQueue? = DispatchQueue(label: "Replicant Server Queue")
    var stateUpdateHandler: ((NWListener.State) -> Void)?
    let logger: Logger
    
    var newConnectionHandler: ((Transmission.Connection) -> Void)?
    var config: ReplicantServerConfig
    var listener: TransmissionListener    
   
    required init(port: Int, replicantConfig: ReplicantServerConfig, logger: Logger) throws
    {
        self.parameters = .tcp
        self.config = replicantConfig
        self.port = port
        self.logger = logger
        
        // Create the listener
        guard let listener = TransmissionListener(port: port, logger: logger) else
        {
            print("\n😮  Listener creation error  😮\n")
            throw ListenerError.initializationError
        }
        self.listener = listener
    }
    
    func accept() -> Connection {
        while true {
            let networkConnection = self.listener.accept()
            
            print("\nReplicant Listener new connection handler called.")
            guard let replicantConnection = makeReplicant(connection: networkConnection)
            else
            {
                print("Unable to convert new connection to a Replicant connection.")
                continue
            }
            
            return replicantConnection
        }
    }
    
    func makeReplicant(connection: Transmission.Connection) -> Transmission.Connection?
    {
        let newConnection = ReplicantServerConnection(connection: connection, parameters: .tcp, replicantConfig: config, logger: logger)
        
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
}

enum ListenerError: Error
{
    case invalidPort
    case initializationError
}
