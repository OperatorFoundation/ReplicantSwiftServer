//
//  File.swift
//  
//
//  Created by Joshua Clark on 11/18/21.
//

import Foundation

import Gardener

struct RunReplicantServerController
{
    var replicantServerIP: String
    let command = Command()
    let git = Git()
    let homeDir = File.homeDirectory().path
    func buildForLinux()
    {
        // Download and build ReplicantSwiftServer on the remote server
        let result = Bootstrap.bootstrap(username: "root", host: replicantServerIP, source: "https://github.com/OperatorFoundation/ReplicantSwiftServer", branch: "main", target: "ReplicantSwiftServer")
        
        if result
        {
            print("Finished building ReplicantSwiftServer.")
        }
        else
        {
            print("Failed to build ReplicantSwiftServer")
        }
    }

    func runReplicantSwiftServer() -> Cancellable? {
        guard let ssh = SSH(username: "root", host: replicantServerIP)
        else
        {
            print("could not ssh into server.")
            return nil
        }
        
        guard let cancellable = ssh.remoteWithCancellation(command: "cd ReplicantSwiftServer; ./run.sh") else {
            print("failed to execute run.sh")
            return nil
        }
        
        return cancellable
    }
}
