//
//  File.swift
//  
//
//  Created by Joshua Clark on 8/20/21.
//

import Foundation

import Gardener

struct PacketCaptureController
{
    var replicantServerIP: String
    let command = Command()
    let git = Git()
    
    func buildForLinux()
    {
        // make sure we're in the home directory
        command.cd("~")
        // Download Moonbounce locally
        git.clone("https://github.com/OperatorFoundation/Moonbounce.git")
        
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
            print("could not ssh into packet capture server.")
            return nil
        }
        
        print("\n current directory:")
        let current = File.currentDirectory()
        print(current)
        
        print("\n contents of directory:")
        let contents = File.contentsOfDirectory(atPath: current)
        print(contents)
        
        command.cd("ReplicantSwiftServer")
        
        guard let cancellable = command.runWithCancellation("./run.sh") else {
            print("failed to execute run.sh")
            return nil
        }
        
        return cancellable
    }
    
    func runMoonbounce() -> Cancellable? {
        command.cd("~/Moonbounce")
        
        guard let cancellable = command.runWithCancellation("xcodebuild", "-product", "testPing", "Moonbounce.xcodeproj", "-scheme", "MoonbounceTests", "-testPlan", "MoonbounceTests", "test") else {
            print("failed to execute Moonbounce test")
            return nil
        }
        
        return cancellable
    }
    
    func runPacketCapture() -> Cancellable?
    {
        // TODO: put these prints on all functions
        print("* beginning runPacketCapture() *")
        // ssh into the server
        guard let ssh = SSH(username: "root", host: replicantServerIP)
        else
        {
            print("could not ssh into packet capture server.")
            return nil
        }
        
        //run tcpdump and wait a while for the server to receive the packets
        guard let cancellable = command.runWithCancellation("tcpdump", "-w", "packets.pcap") else {
            print("failed to run tcpDump")
            return nil
        }
        
        print("* finished runPacketCapture() *")
        
        return cancellable
    }
}
