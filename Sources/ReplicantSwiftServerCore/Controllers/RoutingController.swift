//
//  RoutingController.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/30/18.
//

import Foundation
import Logging

import InternetProtocols
import Transport
import ReplicantSwift
import Flower
import Tun
import Routing
import SwiftHexTools
import NetworkLinux
import TransmissionLinux

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
    
    public func startListening(serverConfig: ServerConfig, replicantConfig: ReplicantServerConfig,  replicantEnabled: Bool)
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

        let port = serverConfig.port
        print("\n! Listening on port \(port)")

        self.replicantEnabled = replicantEnabled
        
        if replicantEnabled
        {
            print("Replicant listener")
            do
            {
                let replicantListener = try ReplicantListener(replicantConfig: replicantConfig, serverConfig: serverConfig, logger: logger)
                replicantListener.stateUpdateHandler = debugListenerStateUpdateHandler
                replicantListener.newTransportConnectionHandler =
                {
                    (replicantConnection) in

                    print("\nNew Replicant connection rececived.")
                    self.consoleIO.writeMessage("New Replicant Connection!")
                    self.process(newReplicantConnection: replicantConnection, port: serverConfig.port)
                }
                
                replicantListener.start(queue: listenerQueue)
                print("! Replicant listener started and listening")
            }
            catch
            {
                print("\nUnable to create ReplicantListener\n")
            }
        }
        else
        {
            print("! Plain listener")
            do
            {
                guard let listener = TransmissionLinux.Listener(port: Int(serverConfig.port.rawValue)) else {return}
                print("started listener")

                while true
                {
                  guard let connection = listener.accept() else {return}
                  print("\nNew plain connection rececived.")
                  self.consoleIO.writeMessage("New plain Connection!")
                  let transport = TransmissionToTransportConnection(connection)
                  self.process(newReplicantConnection: transport, port: serverConfig.port)
                }
            }
            catch
            {
                print("\nUnable to create ReplicantListener\n")
            }
        }

      print("End RoutingController.startListening")
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

        let sendConnection = conduit.transportConnection
        print("sendConnection: \(sendConnection)")

        // FIXME: May not be IPV4
        print("🌷 Transfer from TUN payload: \(data) 🌷")
        let message = Message.IPDataV4(data)
        print("message: \(message)")
        print("🌷 Transfer from TUN created a message: \(message.description) 🌷")

        print("sendConnection type : \(type(of: sendConnection))")
        sendConnection.send(content: message.data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
            {
                (maybeSendError) in

                if let sendError = maybeSendError
                {
                    print("\nReceived a send error: \(sendError)\n")
                    return
                } else {
                    self.logger.debug("finished sending an IPDataV4 message to the client")
                }
            })
        )
    }
    
    func debugListenerStateUpdateHandler(newState: NWListener.State)
    {
        switch newState
        {
            case .ready:
                print("\nListening...\n")
            case .failed(let error):
                print("\nListener failed with error: \(error.localizedDescription)\n")
            case .waiting(let error):
                print("\nListener waiting with error: \(error)\n")
            default:
                print("\nReceived unexpected state: \(newState)\n")
        }
    }
    
    func debugConnectionStateUpdateHandler(newState: NWConnection.State)
    {
        switch newState
        {
            case .cancelled:
                print("Server connection canceled.\n")
            case .failed(let networkError):
                print("Server connection failed with error:  \(networkError)\n")
            case .preparing:
                print("Preparing connection to server.\n")
            case .setup:
                print("Connection in setup phase.\n")
            case .waiting(let waitError):
                print("⏳ Connection waiting with error: \(waitError)\n")
            case .ready:
                print("Connection is Ready\n")
        }
    }

    func process(newReplicantConnection: Transport.Connection, port: NWEndpoint.Port)
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
        
        conduitCollection.addConduit(address: address, transportConnection: newReplicantConnection)

        print("conduit added successfully")
        
        // FIXME - support IPv6
        let ipv4AssignMessage = Message.IPAssignV4(v4)
        newReplicantConnection.writeMessage(message: ipv4AssignMessage)
        {
            (maybeError) in
            
            print("\n🌷 Listener connection handler sent a message.\(ipv4AssignMessage) 🌷")
            guard maybeError == nil else
            {
                print("Error sending IP assignment")
                return
            }
            
            let transferQueue1 = DispatchQueue(label: "Transfer Queue 1")
            
            transferQueue1.async
            {
                print("Starting Transfer")
                self.transfer(from: newReplicantConnection, toAddress: address)
                print("Transfer Finished")
            }
        }
        print("WriteMessage called!")
    }
    
    func transfer(from receiveConnection: Transport.Connection, toAddress sendAddress: String)
    {
        print("Transfer called")
        receiveConnection.readMessages(log: self.logger)
        {
            (message) in
            
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
