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

    @Argument(help: "IP address for the system to build on.")
    var replicantServerIP: String
    
    func run() throws
    {
        let queue = DispatchQueue(label: "packetCaptureQueue")
        let packetCaptureController = PacketCaptureController(replicantServerIP: replicantServerIP)
        var replicantServer: Cancellable? = nil
        var packetCapture: Cancellable? = nil
        var moonbounceTest: Cancellable? = nil
        let scp = SCP(username: "root", host: replicantServerIP)
        
        packetCaptureController.buildForLinux()
        
        queue.async {
            replicantServer = packetCaptureController.runReplicantSwiftServer()
        }
        
        queue.async {
            packetCapture = packetCaptureController.runPacketCapture()
        }
        
        // sleep for 30 seconds
        Thread.sleep(forTimeInterval: 30)
        queue.async {
            moonbounceTest = packetCaptureController.runMoonbounce()
        }
        Thread.sleep(forTimeInterval: 30)
        
        if let unwrappedPacketCapture = packetCapture {
            unwrappedPacketCapture.cancel()
        } else {
            print("packet capture failed")
        }
        
        if let unwrappedMoonbounceTest = moonbounceTest {
            unwrappedMoonbounceTest.cancel()
        } else {
            print("Moonbounce test failed")
        }
        
        if let unwrappedReplicantServer = replicantServer {
            unwrappedReplicantServer.cancel()
        } else {
            print("Replicant server failed to initialize")
        }
        
        if let unwrappedScp = scp {
            //scp root@138.197.196.245:packets.pcap packets.pcap
            unwrappedScp.download(remotePath: "packets.pcap", localPath: "~/packets.pcap")
        } else {
          print("scp unsuccessful")
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

PacketCapture.main()
