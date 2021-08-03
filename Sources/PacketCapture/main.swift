//
//  File.swift
//  
//
//  Created by Joshua Clark on 7/29/21.
//

import ArgumentParser
import Foundation

import Gardener

struct PacketCapture: ParsableCommand
{
    let command = Command()
    let git = Git()
    let scp = SCP("root", "138.197.196.245")
    let queue = DispatchQueue(label: "packetCaptureQueue")
    
    @Argument(help: "IP address for the system to build on.")
    var buildServerIP: String

    @Argument(help: "IP address for the system to test the build on.")
    var testServerIP: String
    
    func validate() throws
    {
        // This pings the server ip and returns nil if it fails
        guard let _ = SSH(username: "root", host: buildServerIP)
        else
        {
            throw ValidationError("'<BuildServerIP>' is not valid.")
        }

        // This pings the server ip and returns nil if it fails
        guard let _ = SSH(username: "root", host: testServerIP)
        else
        {
            throw ValidationError("'<TestServerIP>' is not valid.")
        }
    }
    
    func run()
    {
        var replicantServer: Cancellable? = nil
        var packetCapture: Cancellable? = nil
        var moonbounceTest: Cancellable? = nil
        
        buildForLinux()
        
        queue.async {
            replicantServer = runReplicantSwiftServer()
        }
        
        queue.async {
            packetCapture = runPacketCapture()
        }
        
        // sleep for 30 seconds
        Thread.sleep(forTimeInterval: 30)
        queue.async {
            moonbounceTest = runMoonbounce()
        }
        Thread.sleep(forTimeInterval: 30)
        
        packetCapture.cancel()
        moonbounceTest.cancel()
        replicantServer.cancel()
        
        //scp root@138.197.196.245:packets.pcap packets.pcap
        scp.download("packets.pcap", "~/packets.pcap")
        
    }

    func buildForLinux()
    {
        // make sure we're in the home directory
        command.cd("~")
        
        // Download Moonbounce locally
        git.clone("https://github.com/OperatorFoundation/Moonbounce.git")
        
        // Download and build ReplicantSwiftServer on the remote server
        let result = Bootstrap.bootstrap(username: "root", host: buildServerIP, source: "https://github.com/OperatorFoundation/ReplicantSwiftServer", branch: "main", target: "ReplicantSwiftServer")
        
        if result
        {
            print("Finished building ReplicantSwiftServer.")
        }
        else
        {
            print("Failed to build ReplicantSwiftServer")
        }
    }

    func runReplicantSwiftServer() -> Cancellable {
        guard let ssh = SSH(username: "root", host: testServerIP)
        else
        {
            print("could not ssh into packet capture server.")
            return
        }
        
        command.cd("ReplicantSwiftServer")
        let cancellable = command.runWithCancellation("./run.sh")
        
        return cancellable
    }
    
    func runMoonbounce() -> Cancellable {
        command.cd("~/Moonbounce")
        
        let cancellable = command.runWithCancellation("xcodebuild", "-product", "testPing", "Moonbounce.xcodeproj", "-scheme", "MoonbounceTests", "-testPlan", "MoonbounceTests", "test")
        
        return cancellable
    }
    
    func runPacketCapture()
    {
        // ssh into the server
        guard let ssh = SSH(username: "root", host: testServerIP)
        else
        {
            print("could not ssh into packet capture server.")
            return
        }
        
        //run tcpdump and wait a while for the server to receive the packets
        command.run("tcpdump", "-w", "packets.pcap")
        pause(3000)
    }
}
