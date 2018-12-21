//
//  ReplicantServer.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 12/12/18.
//

import Foundation
import ReplicantSwift
import Replicant

class ReplicantServer
{
    let routingController = RoutingController()
    var lock = DispatchGroup.init()
    
    /// Figure out what the user wants to do.
    func processRequest()
    {
        let argCount = CommandLine.argc
        let argument = CommandLine.arguments[1]
        let (option, value) = getOption(argument)
        
        consoleIO.writeMessage("Argument count: \(argCount) Option: \(option) value: \(value)")
        
        switch option
        {
        case .runServer:
            runMode()
        case .writeClientConfig:
            writeMode()
        default:
            consoleIO.printUsage()
        }
    }

    func getOption(_ option: String) -> (option: OptionType, value: String)
    {
        return (OptionType(value: option), option)
    }
    
    ///ReplicantSwiftServer write <config_template_path> <New_clientConfig_complete_path>
    func writeMode()
    {
        consoleIO.writeMessage("\n📝  Entering write mode.\n")
        
        guard CommandLine.argc == 4
        else
        {
            consoleIO.writeMessage("Incorrect Arguments", to: .error)
            return
        }
        
        // Make sure we have a valid config template
        let configTemplatePath = CommandLine.arguments[2]
        guard let configTemplate = ReplicantConfigTemplate.parseJSON(atPath: configTemplatePath)
        else
        {
            consoleIO.writeMessage("Unable to find a valid client config templatge at path: \(configTemplatePath)", to: .error)
            return
        }
        
        // Get the server public key
        guard let serverPublicKey = PolishServerModel()?.publicKey
        else
        {
            consoleIO.writeMessage("Unable to fetch server public key", to: .error)
            return
        }
        
        // Attempt to create the new client config at the given path
        let newConfigPath = CommandLine.arguments[3]
        let configCreated = configTemplate.createConfig(atPath: newConfigPath, withServerKey: serverPublicKey)
        
        guard configCreated
        else
        {
            consoleIO.writeMessage("\nUnable to save config to path:\(newConfigPath)\nUsing template at path:\(configTemplatePath)\n", to: .error)
            return
        }

        consoleIO.writeMessage("Created a new Replicant client config at path:\(newConfigPath)")
    }
    
    /// ReplicantSwiftServer run <path_to_replicant_server_config> <path_to_server_config>
    func runMode()
    {
        consoleIO.writeMessage("🏃🏽‍♀️  Entering run mode.")
        
        guard CommandLine.argc == 4
        else
        {
            return
        }
        
        // Fetch and parse Replicant Config at path
        let replicantConfigPath = CommandLine.arguments[2]
        guard let replicantServerConfig = ReplicantServerConfig.parseJSON(atPath: replicantConfigPath)
            else
        {
            print("\nUnable to initialize server, config file not found at: \(replicantConfigPath)\n")
            return
        }
        
        // Fetch and parse server config at path.
        let serverConfigPath = CommandLine.arguments[3]
        guard let serverConfig = ServerConfig.parseJSON(atPath:serverConfigPath)
        else
        {
            consoleIO.writeMessage("Unable to parse server config file at path: \(serverConfigPath)", to: .error)
            return
        }
        
        guard let replicantServerModel = ReplicantServerModel(withConfig: replicantServerConfig)
            else
        {
            print("Unable to create server model using config: \(serverConfig)")
            return
        }
        
        lock.enter()
        
        ///FIXME: User should control whether transport is enabled
        routingController.startListening(serverConfig: serverConfig, replicantConfig: replicantServerConfig, replicantEnabled: true)
        lock.wait()
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
