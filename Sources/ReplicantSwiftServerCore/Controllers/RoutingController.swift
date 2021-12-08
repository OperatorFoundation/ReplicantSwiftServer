//
//  RoutingController.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/30/18.
//

import Foundation
import Logging

import InternetProtocols
import ReplicantSwift
import Flower
import Tun
import Routing
import SwiftHexTools
import Net
import Transmission
import Transport

import TransmissionTransport

public class RoutingController
{
    let logger: Logger
    let consoleIO = ConsoleIO()
    let listenerQueue = DispatchQueue(label: "Listener")
    var tun: TunDevice?
    let packetSize: Int = 2000 // FIXME - set this to a thoughtful value
    var packetCount = 0
    
    var conduitCollection = ConduitCollection()
    var replicantEnabled = true
    var pool = AddressPool()
    
    public required init?(logger: Logger)
    {
        self.logger = logger
    }
    
    public func startListening(serverConfig: ServerConfig, replicantConfig: ReplicantServerConfig, replicantEnabled: Bool)
    {
        print("RoutingController.startListening")
        
        guard let tunDevice = TunDevice(address: "10.0.0.1", reader: self.transferFromTUN)
        else
        {
            print("🚨 Failed to create tun device. 🚨")
            //return nil
            return
        }

        self.tun = tunDevice

        //setup routing (nat, ip forwarding, and mtu)
        // FIXME - server config should include an interface name to listen for connections on, for now it's static...
        let internetInterface: String = "eth0"
        print("⚠️ Setting internet interface to value: \(internetInterface)! Update code to set value from config file. ⚠️")

        guard let tunName = tunDevice.maybeName else {
            print("could not find tun name")
            return
        }
        setMTU(interface: tunName, mtu: 1380)
        print("tun Name: \(tunName)")
        //setAddressV6(interfaceName: tunName, addressString: tunAv6, subnetPrefix: 64)

        setIPv4Forwarding(setTo: true)
        //setIPv6Forwarding(setTo: true)

        print("[S] Deleting all ipv4 NAT entries for \(internetInterface)")
        while deleteServerNAT(serverPublicInterface: internetInterface) {}
        

        //        print("[S] Deleting all ipv6 NAT entries for \(internetInterface)")
        //        var result6 = false
        //        while !result6
        //        {
        //            result6 = deleteServerNATv6(serverPublicInterface: internetInterface)
        //        }

        configServerNAT(serverPublicInterface: internetInterface)
        print("[S] Current ipv4 NAT: \n\n\(getNAT())\n\n")

        //        configServerNATv6(serverPublicInterface: internetInterface)
        //        print("[S] Current ipv6 NAT: \n\n\(getNATv6())\n\n")

        let port = Int(serverConfig.port.rawValue)
        print("\n! Listening on port \(port)")

        self.replicantEnabled = replicantEnabled
        
        print("Replicant listener")

        guard let flowerListener = FlowerListener(port: port, replicantConfig: replicantConfig, logger: logger) else
        {
            print("unable to create Flower listener")
            return
        }

        while true
        {
            let flowerConnection = flowerListener.accept()
            self.consoleIO.writeMessage("New Replicant Connection!")
            self.process(flowerConnection: flowerConnection, port: serverConfig.port)
        }
    }
    
    func transferFromTUN(data: Data) {
        print("🚇 TransferFromTUN called 🚇")
        packetCount += 1
        print("packet count: \(packetCount)")
        print("Number of bytes: \(data.count)")
        print(data.hex)
        print(data.array)
        
        //FIXME: add IPv6 support
        guard let ipv4 = IPv4(data: data) else
        {
            print("no ipv4")
            return
        }

        print("IPV4 address: \(ipv4)")
        print(ipv4.description)
        
        let destAddressData = ipv4.destinationAddress
        let destAddress = "\(destAddressData[0].string).\(destAddressData[1].string).\(destAddressData[2].string).\(destAddressData[3].string)"
        print("destAddress: \(destAddress)")

        guard let conduit = self.conduitCollection.getConduit(with: destAddress)
        else {
            print("Could not find Conduit")
            return
        }
        print("conduit: \(conduit)")

        let flowerConnection = conduit.flowerConnection

        print("🌷 Transfer from TUN payload: \(data) 🌷")
        let message = Message.IPDataV4(data)
        print("message: \(message)")
        print("🌷 Transfer from TUN created a message: \(message.description) 🌷")

        flowerConnection.writeMessage(message: message)
    }

    func process(flowerConnection: FlowerConnection, port: NWEndpoint.Port)
    {
        print("Routing controller listener connection handler called.")

        // FIXME - support IPv6
        guard let address = pool.allocate() else
        {
            print("Error getting connection address in connection handler.")
            return
        }
        
        guard let v4 = IPv4Address(address) else
        {
            print("Unable to get IPV4 address in connection handler.")
            return
        }
        
        conduitCollection.addConduit(address: address, flowerConnection: flowerConnection)

        print("conduit added successfully")
        
        // FIXME - support IPv6
        let ipv4AssignMessage = Message.IPAssignV4(v4)
        flowerConnection.writeMessage(message: ipv4AssignMessage)
        
        let transferQueue1 = DispatchQueue(label: "Transfer Queue 1")
        
        transferQueue1.async
        {
            print("Starting Transfer")
            self.transfer(from: flowerConnection, toAddress: address)
            print("Transfer Finished")
        }
        
        print("WriteMessage called!")
    }
    
    func transfer(from receiveConnection: FlowerConnection, toAddress sendAddress: String)
    {
        print("Transfer called")
        while true {
            let maybeMessage = receiveConnection.readMessage()

            guard let message = maybeMessage else {
                print("transfer message not received")
                return
            }
            
            print("🌷 Received a message: \(message.description) 🌷")
            
            switch message
            {
                case .IPDataV4(let payload):
                    print("\n🚢 Reading an ipv4 message 🚢")
                    let now = Date()
                    
                    print("Checking for sourceAddress")
                    guard let sourceAddress = IPv4Address(sendAddress) else
                    {
                        print("sourceAddress is nil")
                        return
                    }
                    
                    print("Checking for IPV4 Packet")
                    guard let ipv4 = IPv4(data: payload)
                    else {
                        print("Packet was not IPV4")
                        return
                    }
                    
                    print("checking sourceAddress value")
                    guard ipv4.sourceAddress == sourceAddress.rawValue else
                    {
                        print(ipv4.description)
                        print("sourceAddress value was unexpected. packet:\(ipv4.sourceAddress.array), assigned ip:\(sourceAddress.rawValue.array)")
                        
                        return
                    }

                    print("Checking for tun device")
                    if let ourTun = self.tun{

                        let bytesWritten = ourTun.writeBytes(payload)
                        print("tun device wrote \(bytesWritten) bytes.")
                        print("[S] Current ipv4 NAT: \n\n\(getNAT())\n\n")
                    } else {
                        print("no tun device")
                        return
                    }
                case .IPDataV6(let payload):
                    print("\nReading an IPV6 message.")
                    if let ourTun = self.tun {
                        let bytesWritten = ourTun.writeBytes(payload)
                        print("tun device wrote \(bytesWritten) bytes.")
                    }
                default:
                    print("\nUnsupported message type")
                    return
            }
        }
    }
}

