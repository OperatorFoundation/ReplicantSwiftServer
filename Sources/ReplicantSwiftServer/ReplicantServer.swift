//
//  ReplicantServer.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 12/12/18.
//

import Foundation
import Logging

import Datable
import ReplicantSwiftServerCore
import ReplicantSwift
import Net
import Transport

class ReplicantServer
{

    init?()
    {
        // Setup the logger
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        appLog.logLevel = .debug
    }
    
    /// Figure out what the user wants to do.
    func processRequest()
    {
        if CommandLine.argc < 2
        {
            //Handle invalid command
            consoleIO.printUsage()
        }
        else
        {
            let argument = CommandLine.arguments[1]
            let (option, _) = getOption(argument)
            
            switch option
            {
                case .runServer:
                    runMode()
                default:
                    consoleIO.printUsage()
            }
        }
    }

    func getOption(_ option: String) -> (option: OptionType, value: String)
    {
        return (OptionType(value: option), option)
    }

    /// ReplicantSwiftServer run <path_to_replicant_server_config> <path_to_server_config>
    func runMode()
    {
        // FIXME: Currently everythig is just hard-coded defaults
        // Configs should be provided by the user
        guard let serverReplicantConfig = ReplicantServerConfig(polish: nil, toneBurst: nil)
        else
        {
            print("failed to create Replicant Config")
            return
        }
        
        let serverConfig = ServerConfig(withPort: NWEndpoint.Port(integerLiteral: 1234), andHost: NWEndpoint.Host.ipv4(IPv4Address("0.0.0.0")!))

        guard let routingController = RoutingController(logger: appLog)
        else
        {
            return
        }

        ///FIXME: User should control whether transport is enabled
        routingController.startListening(serverConfig: serverConfig, replicantConfig: serverReplicantConfig, replicantEnabled: true)        
    }
}

enum OptionType: String
{
    case help = "-h"
    case runServer = "run"
    case writeClientConfig = "write"
    case unknown
    
    init(value: String)
    {
        switch value
        {
        case "run":
            self = .runServer
        case "write":
            self = .writeClientConfig
        case "-h":
            self = .help
        default:
            self = .unknown
        }
    }
}
