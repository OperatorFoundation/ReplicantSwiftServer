//
//  ReplicantServer.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 12/12/18.
//

import Foundation

class ReplicantServer
{
    var lock = DispatchGroup.init()
    let routingController = RoutingController()
    
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
    
    func writeMode()
    {
        guard CommandLine.argc == 3
        else
        {
            consoleIO.writeMessage("Incorrect Arguments", to: .error)
            return
        }
        
        let configTemplateString = CommandLine.arguments[2]
        consoleIO.writeMessage("📝  Entering write mode.")
    }
    
    func runMode()
    {
        consoleIO.writeMessage("🏃🏽‍♀️  Entering run mode.")
        lock.enter()
        //TODO: get port from config
        // routingController.startListening(onPort: portString, replicantEnabled: true)
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
