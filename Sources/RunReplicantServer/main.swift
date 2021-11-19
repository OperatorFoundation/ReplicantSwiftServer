//
//  File.swift
//  
//
//  Created by Joshua Clark on 11/18/21.
//

import ArgumentParser
import Foundation

import Gardener

struct RunReplicantServer: ParsableCommand
{

    @Argument(help: "IP address for the system to build on.")
    var replicantServerIP: String
    
    func run() throws
    {
        let queue = DispatchQueue(label: "runReplicantServerQueue")
        let runReplicantServerController = RunReplicantServerController(replicantServerIP: replicantServerIP)
        var replicantServer: Cancellable? = nil
        let scp = SCP(username: "root", host: replicantServerIP)
        let homeDir = File.homeDirectory().path
        
        runReplicantServerController.buildForLinux()
        
        queue.async {
            replicantServer = runReplicantServerController.runReplicantSwiftServer()
        }
    }

    func validate() throws
    {
        // This pings the server ip and returns nil if it fails
        guard let _ = SSH(username: "root", host: replicantServerIP)
        else
        {
            throw ValidationError("'<BuildServerIP>' is not valid.")
        }
    }
}

RunReplicantServer.main()
