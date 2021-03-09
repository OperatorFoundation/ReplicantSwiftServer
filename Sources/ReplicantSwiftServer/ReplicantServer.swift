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
import Transport

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

class ReplicantServer
{
    let routingController: RoutingController
    
    init?()
    {
        // Setup the logger
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        appLog.logLevel = .debug
        
        guard let rController = RoutingController(logger: appLog)
        else
        {
            return nil
        }
        
        routingController = rController
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
//                case .writeClientConfig:
//                    writeMode()
//                    
                default:
                    consoleIO.printUsage()
            }
        }
    }

    func getOption(_ option: String) -> (option: OptionType, value: String)
    {
        return (OptionType(value: option), option)
    }
    
    ///ReplicantSwiftServer write <config_template_path> <New_clientConfig_complete_path>
//    func writeMode()
//    {
//        consoleIO.writeMessage("\n📝  Entering write mode.\n")
//
//        guard CommandLine.argc == 4
//        else
//        {
//            consoleIO.writeMessage("Incorrect Arguments", to: .error)
//            return
//        }
//
//        // Make sure we have a valid config template
//        let configTemplatePath = CommandLine.arguments[2]
//        guard let configTemplate = ReplicantConfigTemplate.parseJSON(atPath: configTemplatePath)
//        else
//        {
//            consoleIO.writeMessage("Unable to find a valid client config template at path: \(configTemplatePath)", to: .error)
//            return
//        }
//
//        // Get the server public key
//        guard let serverPublicKey = SilverServerModel(logQueue: routingController.logQueue)?.publicKey
//        else
//        {
//            consoleIO.writeMessage("Unable to fetch server public key", to: .error)
//            return
//        }
//
//        // Attempt to create the new client config at the given path
//        let newConfigPath = CommandLine.arguments[3]
//        let configCreated = configTemplate.createConfig(atPath: newConfigPath, serverPublicKey: serverPublicKey)
//
//        guard configCreated
//        else
//        {
//            consoleIO.writeMessage("\nUnable to save config to path:\(newConfigPath)\nUsing template at path:\(configTemplatePath)\n", to: .error)
//            return
//        }
//
//        consoleIO.writeMessage("Created a new Replicant client config at path:\(newConfigPath)")
//    }
    
    /// ReplicantSwiftServer run <path_to_replicant_server_config> <path_to_server_config>
    func runMode()
    {
        consoleIO.writeMessage("\n🏃🏽‍♀️  Entering run mode.")
        
        // Get the server public key
//        guard let polishServerModel = SilverServerModel(logQueue: routingController.logQueue)
//        else
//        {
//            consoleIO.writeMessage("Unable to initialize a Polish server model")
//            return
//        }
//
//        let serverPublicKey = polishServerModel.publicKey
//        let keyString = serverPublicKey.x963Representation.base64EncodedString
//        consoleIO.writeMessage("🚪  This server's public key is: \(String(describing: keyString))  🗝")

        // FIXME - This should be handled in processRequest and usage should be printed.
//        guard CommandLine.argc == 4 else
//        {
//            return
//        }
//
//        // Fetch and parse Replicant Config at path
//        let replicantConfigPath = CommandLine.arguments[2]
//        guard let replicantServerConfig = ReplicantServerConfig.parseJSON(atPath: replicantConfigPath) else
//        {
//            print("\nUnable to initialize server, config file not found at: \(replicantConfigPath)\n")
//            return
//        }
//
//        // Fetch and parse server config at path.
//        let serverConfigPath = CommandLine.arguments[3]
//        guard let serverConfig = ServerConfig.parseJSON(atPath:serverConfigPath) else
//        {
//            consoleIO.writeMessage("Unable to parse server config file at path: \(serverConfigPath)", to: .error)
//            return
//        }
//
//        guard let replicantServerModel = ReplicantServerModel(withConfig: replicantServerConfig, logQueue: routingController.logQueue) else
//        {
//            print("Unable to create server model using config: \(serverConfig)")
//            return
//        }
        
        // FIXME: Currently everythig is just hard-coded defaults
        // Configs should be provided by the user
        guard let serverReplicantConfig = ReplicantServerConfig(polish: nil, toneBurst: nil)
        else
        {
            print("failed to create Replicant Config")
            return
        }
        
        let serverConfig = ServerConfig(withPort: NWEndpoint.Port(integerLiteral: 1234), andHost: NWEndpoint.Host.ipv4(IPv4Address("0.0.0.0")!))

        ///FIXME: User should control whether transport is enabled
        routingController.startListening(serverConfig: serverConfig, replicantConfig: serverReplicantConfig, replicantEnabled: false)
        
        // FIXME - what's the right way to do this?
        while true
        {
            sleep(100000)
        }
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
