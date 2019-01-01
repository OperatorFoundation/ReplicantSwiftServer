//
//  ConsoleIO.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 12/12/18.
//

import Foundation

class ConsoleIO
{
    enum OutputType
    {
        case error
        case standard
    }
    
    func writeMessage(_ message: String, to: OutputType = .standard)
    {
        switch to
        {
        case .standard:
            print("\(message)")
        case .error:
            fputs("Error: \(message)\n", stderr)
        }
    }
    
    func printUsage()
    {
        let executableName = (CommandLine.arguments[0] as NSString).lastPathComponent
        
        writeMessage("usage:")
        writeMessage("\(executableName) run <path_to_replicant.conf> <path_to_server.conf>")
        writeMessage("\(executableName) write <path_to_client.conf_template> <destination_path_for_client.conf>")
        writeMessage("\(executableName) -h to show usage information")
    }
}
