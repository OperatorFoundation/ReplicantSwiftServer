//
//  Launch.swift
//  
//
//  Created by Mafalda on 1/18/22.
//

import ArgumentParser
import Foundation
import Logging

import ReplicantSwift
import ReplicantSwiftServerCore
import Transport
import Net

extension Command
{
    struct Launch: ParsableCommand
    {
        enum Error: LocalizedError
        {
            case configError
            
            var errorDescription: String?
            {
                switch self
                {
                    case .configError:
                        return "We were unable to generate valid configuration settings for the server."
                }
            }
        }
        
        static var configuration: CommandConfiguration
        {
            .init(
                commandName: "run",
                abstract: "Launch a Replicant Server"
            )
        }
        
        func run() throws
        {
            // Setup the logger
            LoggingSystem.bootstrap(StreamLogHandler.standardError)
            appLog.logLevel = .debug
            
            // FIXME: Currently everything is just hard-coded defaults
            // Configs should be provided by the user
            guard let serverReplicantConfig = ReplicantServerConfig(polish: nil, toneBurst: nil)
            else
            {
                throw Error.configError
            }
            
            let serverConfig = ServerConfig(withPort: NWEndpoint.Port(integerLiteral: 1234), andHost: NWEndpoint.Host.ipv4(IPv4Address("0.0.0.0")!))
            let routingController = RoutingController(logger: appLog)

            ///FIXME: User should control whether transport is enabled
            routingController.startListening(serverConfig: serverConfig, replicantConfig: serverReplicantConfig, replicantEnabled: true)
        }
        
    }
}
