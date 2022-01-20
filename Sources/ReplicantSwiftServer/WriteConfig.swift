//
//  WriteConfig.swift
//  
//
//  Created by Mafalda on 1/18/22.
//

import ArgumentParser
import Foundation
import Logging

import ReplicantSwift
import ReplicantSwiftServerCore

extension Command
{
    struct WriteConfig: ParsableCommand
    {
        enum Error: LocalizedError
        {
            case templateNotFound
            case templateInvalid
            case serverKeyNotFound
            case savePathIsNotDirectory
            case saveFailure
            
            var errorDescription: String?
            {
                switch self
                {
                    case .templateNotFound:
                        return "Failed to find the config template at the provided path."
                    case .templateInvalid:
                        return "The file at the provided path is not a valid Replicant config template."
                    case .serverKeyNotFound:
                        return "Failed to retrieve the server key."
                    case .savePathIsNotDirectory:
                        return "The provided save path is not a directory."
                    case .saveFailure:
                        return "Failed to save the config file to the provided directory."
                }
            }
        }
        
        static var configuration: CommandConfiguration
        {
            .init(
                commandName: "config",
                abstract: "Writes a config file to the specified save directory using the template at the specified path."
              )
        }
        
        @Argument(help:"The file path to the config template.")
        var templatePath: String
        
        @Argument(help:"The directory path where the config should be saved.")
        var saveDirectoryPath: String
        
        func validate() throws
        {
            guard FileManager.default.fileExists(atPath: templatePath)
            else
            {
                throw Error.templateNotFound
            }
            
            let dirURL = URL(fileURLWithPath: saveDirectoryPath)
            guard dirURL.hasDirectoryPath
            else
            {
                throw Error.savePathIsNotDirectory
            }
        }
        
        func run() throws
        {
            // Setup the logger
            LoggingSystem.bootstrap(StreamLogHandler.standardError)
            appLog.logLevel = .debug
            
            print("\n📝  Entering write mode.\n")
    
            // Make sure we have a valid config template
            guard let configTemplate = ReplicantConfigTemplate.parseJSON(atPath: templatePath)
            else
            {
                print("Unable to find a valid client config template at path: \(templatePath)")
                throw Error.templateInvalid
            }
    
            guard let serverPublicKey = SilverController(logger: appLog).fetchServerPublicKey()
            else
            {
                throw Error.serverKeyNotFound
            }
    
            // Attempt to create the new client config at the given path
            // TODO: Get IP and Port
            let configCreated = configTemplatecreateConfig(atPath: saveDirectoryPath, serverIP: "ServerIP", port: 1111, serverPublicKey: serverPublicKey)
    
            guard configCreated
            else
            {
                print("\nUnable to save config to path:\(newConfigPath)\nUsing template at path:\(configTemplatePath)\n")
                throw Error.saveFailure
            }
    
            print("Created a new Replicant client config at path:\(newConfigPath)")
        }
    }
}
