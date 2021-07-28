import XCTest
import ReplicantSwift
import Network
import Tun

@testable import ReplicantSwiftServerCore

import class Foundation.Bundle
import SwiftQueue

final class ReplicantSwiftServerTests: XCTestCase
{
    
    func testSendReceivePackets()
    {
        /*
         define destination address and port
         setup a tun interface for reading and writing packets
         construct a tcp SYN packet using internet protocols
         send the SYN packet out tun interface
         packet gets routed by os from TUN to internet destination
         internet destination sends a syn-ack packet to OS, OS forwards to TUN
         read out packet from TUN
         If we get a matching packet, then test passes
         */
        print("Sleeping 2 seconds to allow debugger to attach to process...")
        sleep(2)
        let destinationAddress: Data = Data(array: [161,35,13,201])
        
        
        let address = "10.2.0.1"
        
        print("Address: \(address)")
        
        var packetCount = 0
        
        let reader: (Data, UInt32) -> Void =
        {
            data, protocolNumber in
            
            packetCount += 1
            print("packet count: \(packetCount)")
            print("protocolNumber: \(protocolNumber)")
            print("Number of bytes: \(data.count)")
            print("Data: ")
            //printDataBytes(bytes: data, hexDumpFormat: true, seperator: "", decimal: false)
        }
        
        guard let tun = TunDevice(address: address, reader: reader) else
        {
            XCTFail()
            return
        }
      
        
        print("Sleeping 15 seconds to allow wireshark to attach to interface...")
        sleep(15)
        
//        let dataToSend = Data(array: [
//            0x45, 0x00, 0x00, 0x40, 0x00, 0x00, 0x40, 0x00, 0x40, 0x06, 0x26, 0xb3, 0x0a, 0x02, 0x00, 0x01, 0x0a, 0x02, 0x00, 0x01, 0xc8, 0xb1, 0x00, 0x16, 0x25, 0x4b, 0x70, 0x3e, 0x00, 0x00, 0x00, 0x00, 0xb0, 0xc2, 0xff, 0xff, 0x7e, 0x2f, 0x00, 0x00, 0x02, 0x04, 0x05, 0xb4, 0x01, 0x03, 0x03, 0x06, 0x01, 0x01, 0x08, 0x0a, 0x5a, 0xc1, 0xea, 0xf4, 0x00, 0x00, 0x00, 0x00, 0x04, 0x02, 0x00, 0x00
//        ])
        
        let hexToSend = "4500004000004000400600007f0000017f000001c40d13ad6d4e7ed500000000b002fffffe34000002043fd8010303060101080a175fb6580000000004020000"
        let dataToSend = hexToSend.hexadecimal!
        
       // printDataBytes(bytes: dataToSend, hexDumpFormat: true, seperator: "", decimal: false)
        tun.writeBytes(dataToSend)
        sleep(1)
        tun.writeBytes(dataToSend)
        sleep(1)
        tun.writeBytes(dataToSend)
        sleep(1)
        tun.writeBytes(dataToSend)
        sleep(1)
        tun.writeBytes(dataToSend)
        sleep(1)
        tun.writeBytes(dataToSend)
        sleep(1)
        
    }

//    func testCreateReplicantConfigTemplate()
//    {
//        let chunkSize: UInt16 = 1440
//        let chunkTimeout: Int = 1000
//
////        guard let addSequence = SequenceModel(sequence: "Hello, hello!".data, length: 120)
////            else
////        {
////            print("\nUnable to generate an add sequence.\n")
////            XCTFail()
////            return
////        }
////
////        guard let removeSequence = SequenceModel(sequence: "Goodbye!".data, length: 200)
////            else
////        {
////            print("\nUnable to generate a remove sequence.\n")
////            XCTFail()
////            return
////        }
//
//
//        guard let directory = getApplicationDirectory(), let configTemplate: ReplicantConfigTemplate = ReplicantConfigTemplate(polish: nil, toneBurst: nil)
//        else
//        {
//            return
//        }
//
//        guard let jsonData = configTemplate.createJSON()
//            else
//        {
//            return
//        }
//
//        let filePath = directory.appendingPathComponent("ReplicantConfigTemplate.conf").path
//
//        FileManager.default.createFile(atPath: filePath, contents: jsonData, attributes: nil)
//        print("\nSaved a Replicant config template to: \(directory)\n")
//    }
    
//    func testReplicantServerConfig()
//    {
//        let logQueue = Queue<String>()
//        guard let polishServer = SilverServerModel(logQueue: logQueue)
//        else
//        {
//            print("\nUnable to generate a key for the server\n")
//            XCTFail()
//            return
//        }
//
//        guard let addSequence = SequenceModel(sequence: "Hello, hello!".data, length: 120)
//        else
//        {
//            print("\nUnable to generate an add sequence.\n")
//            XCTFail()
//            return
//        }
//
//        guard let removeSequence = SequenceModel(sequence: "Goodbye!".data, length: 200)
//        else
//        {
//            print("\nUnable to generate a remove sequence.\n")
//            XCTFail()
//            return
//        }
//
//        let publicKey = polishServer.publicKey
//
//        guard let whalesong = WhalesongServer(addSequences: [addSequence], removeSequences: [removeSequence]) else
//        {
//            print("\nUnable to initialize ToneBurst.\n")
//            XCTFail()
//            return
//        }
//
//        let toneBurst: ToneBurstServerConfig = ToneBurstServerConfig.whalesong(server: whalesong)
//
//        // Create a test ReplicantServerConfig
//        guard let replicantConfig = ReplicantServerConfig(chunkSize: 800, chunkTimeout: 120, toneBurst: toneBurst)
//        else
//        {
//            print("\nUnable to create ReplicantServer config.\n")
//            XCTFail()
//            return
//        }
//
//        // Convert config to JSON
//        guard let jsonData = replicantConfig.createJSON()
//            else
//        {
//            XCTFail()
//            return
//        }
//
//        // Save JSON to the app directory
//        guard let appDirectoryURL = getApplicationDirectory()
//        else
//        {
//            XCTFail()
//            return
//        }
//
//        let fileManager = FileManager.default
//        let fileName = "ReplicantServer.config"
//        let path = appDirectoryURL.appendingPathComponent(fileName).path
//        let configCreated = fileManager.createFile(atPath: path, contents: jsonData)
//
//        XCTAssert(configCreated)
//    }
    
    func testServerConfig()
    {
        guard let port = NWEndpoint.Port(rawValue: 51820)
        else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        let serverConfig = ServerConfig(withPort: port, andHost: NWEndpoint.Host("0.0.0.0"))
        
        guard let jsonData = serverConfig.createJSON()
        else
        {
            print("\nUnable to convert ServerConfig to JSON.\n")
            XCTFail()
            return
        }
        
        guard let appDirectoryURL = getApplicationDirectory()
            else
        {
            XCTFail()
            return
        }
        
        let fileManager = FileManager.default
        let fileName = "Server.config"
        let path = appDirectoryURL.appendingPathComponent(fileName).path
        let configCreated = fileManager.createFile(atPath: path, contents: jsonData)
        
        XCTAssert(configCreated)
    }
    
    func testEncryptDecrypt()
    {
        
    }
    
    func testConnection()
    {
        let chunkSize: UInt16 = 2000
       // let chunkTimeout: Int = 1000
        let unencryptedChunkSize = chunkSize - UInt16(2)
        let testIPString = "192.168.1.72"
        let testPort: UInt16 = 1234
//        guard let serverPublicKey = Data(base64Encoded: "BL7+Vd087+p/roRp6jSzIWzG3qXhk2S4aefLcYjwRtxGanWUoeoIWmMkAHfiF11vA9d6rhiSjPDL0WFGiSr/Et+wwG7gOrLf8yovmtgSJlooqa7lcMtipTxegPAYtd5yZg==")
//        else
//        {
//            print("Unable to get base64 encoded key from the provided string.")
//            XCTFail()
//            return
//        }
        
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }

//        guard let removeSequence = SequenceModel(sequence: "Hello, hello!".data, length: 120)
//            else
//        {
//            print("\nUnable to generate an add sequence.\n")
//            XCTFail()
//            return
//        }
//
//        guard let addSequence = SequenceModel(sequence: "Goodbye!".data, length: 200)
//            else
//        {
//            print("\nUnable to generate a remove sequence.\n")
//            XCTFail()
//            return
//        }
  
//        guard let whalesong = WhalesongClient(addSequences: [addSequence], removeSequences: [removeSequence]) else
//        {
//            print("Failed to initialize ToneBurst.")
//            XCTFail()
//            return
//        }

        //let toneburst = ToneBurstClientConfig.whalesong(client: whalesong)
        
        // Make a Client Connection
        guard let replicantClientConfig = ReplicantConfig(polish: nil, toneBurst: nil)
            else
        {
            print("\nUnable to create ReplicantClient config.\n")
            XCTFail()
            return
        }
        
        let clientConnectionFactory = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig)
        guard var clientConnection = clientConnectionFactory.connect(using: .tcp)
        else
        {
            XCTFail()
            return
        }
        
        clientConnection.stateUpdateHandler =
        {
            state in

            switch state
            {
                case NWConnection.State.ready:
                    connected.fulfill()
                    clientConnection.send(content: Data(repeating: 0x0A, count: Int(unencryptedChunkSize)), contentContext: NWConnection.ContentContext.defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
                        {
                            (maybeError) in
                            
                            if let error = maybeError
                            {
                                print("\nreceived an error on client connection send: \(error)\n")
                                XCTFail()
                                return
                            }
                            
                            sent.fulfill()
                    }))
                default:
                    print("\nReceived a state other than ready: \(state)\n")
                    return
            }
        }
        
        clientConnection.start(queue: .global())
        
        wait(for: [connected, sent], timeout: 10)
    }
    
    func getApplicationDirectory() -> URL?
    {
        let directoryName = "org.OperatorFoundation.ReplicantSwiftServer"
        
        let fileManager = FileManager.default
        var directoryPath: URL
        
        // Find the application support directory in the home directory.
        let appSupportDir = fileManager.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)
        
        guard appSupportDir.count > 0
            else
        {
            //FIXME: This is the approach taken in the apple docs but...
            print("Something went wrong, the app support directory is empty.")
            return nil
        }
        
        // Append the bundle ID to the URL for the
        // Application Support directory
        directoryPath = appSupportDir[0].appendingPathComponent(directoryName)
        
        // If the directory does not exist, this method creates it.
        // This method is only available in macOS 10.7 and iOS 5.0 or later.

        do
        {
            try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
            print("\nCreated a directory at: \(directoryPath)\n")
        }
        catch (let error)
        {
            print("\nEncountered an error attempting to create our application support directory: \(error)\n")
            return nil
        }
        
        return directoryPath
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }
}
extension String
{
    var hexadecimal: Data?
    {
        var data = Data(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
}
