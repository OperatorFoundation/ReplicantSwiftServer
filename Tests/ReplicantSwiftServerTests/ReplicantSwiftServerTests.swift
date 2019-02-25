import XCTest
import ReplicantSwift
import Replicant
import Network

@testable import ReplicantSwiftServerCore

import class Foundation.Bundle

final class ReplicantSwiftServerTests: XCTestCase
{
    
    func testCreateReplicantConfigTemplate()
    {
        let chunkSize: UInt16 = 1440
        let chunkTimeout: Int = 1000
        
//        guard let addSequence = SequenceModel(sequence: "Hello, hello!".data, length: 120)
//            else
//        {
//            print("\nUnable to generate an add sequence.\n")
//            XCTFail()
//            return
//        }
//
//        guard let removeSequence = SequenceModel(sequence: "Goodbye!".data, length: 200)
//            else
//        {
//            print("\nUnable to generate a remove sequence.\n")
//            XCTFail()
//            return
//        }
        
        
        guard let directory = getApplicationDirectory(), let configTemplate: ReplicantConfigTemplate = ReplicantConfigTemplate(chunkSize: chunkSize, chunkTimeout: chunkTimeout, toneBurst: nil)
        else
        {
            return
        }
        
        guard let jsonData = configTemplate.createJSON()
            else
        {
            return
        }
        
        let filePath = directory.appendingPathComponent("ReplicantConfigTemplate.conf").path
        
        FileManager.default.createFile(atPath: filePath, contents: jsonData, attributes: nil)
        print("\nSaved a Replicant config template to: \(directory)\n")
    }
    
    func testReplicantServerConfig()
    {
        guard let polishServer = PolishServerModel()
        else
        {
            print("\nUnable to generate a key for the server\n")
            XCTFail()
            return
        }
        
        guard let addSequence = SequenceModel(sequence: "Hello, hello!".data, length: 120)
        else
        {
            print("\nUnable to generate an add sequence.\n")
            XCTFail()
            return
        }
    
        guard let removeSequence = SequenceModel(sequence: "Goodbye!".data, length: 200)
        else
        {
            print("\nUnable to generate a remove sequence.\n")
            XCTFail()
            return
        }
        
        let publicKey = polishServer.publicKey
        
        guard let whalesong = WhalesongServer(addSequences: [addSequence], removeSequences: [removeSequence]) else
        {
            print("\nUnable to initialize ToneBurst.\n")
            XCTFail()
            return
        }
        
        let toneBurst: ToneBurstServerConfig = ToneBurstServerConfig.whalesong(server: whalesong)
        
        // Create a test ReplicantServerConfig
        guard let replicantConfig = ReplicantServerConfig(chunkSize: 800, chunkTimeout: 120, toneBurst: toneBurst)
        else
        {
            print("\nUnable to create ReplicantServer config.\n")
            XCTFail()
            return
        }
        
        // Convert config to JSON
        guard let jsonData = replicantConfig.createJSON()
            else
        {
            XCTFail()
            return
        }
        
        // Save JSON to the app directory
        guard let appDirectoryURL = getApplicationDirectory()
        else
        {
            XCTFail()
            return
        }
        
        let fileManager = FileManager.default
        let fileName = "ReplicantServer.config"
        let path = appDirectoryURL.appendingPathComponent(fileName).path
        let configCreated = fileManager.createFile(atPath: path, contents: jsonData)
        
        XCTAssert(configCreated)
    }
    
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
    
    func testConnection()
    {
        let chunkSize: UInt16 = 2000
        let chunkTimeout: Int = 1000
        let unencryptedChunkSize = chunkSize - UInt16(aesOverheadSize + 2)
        let testIPString = "192.168.1.72"
        let testPort: UInt16 = 1234
        guard let serverPublicKey = Data(base64Encoded: "BL7+Vd087+p/roRp6jSzIWzG3qXhk2S4aefLcYjwRtxGanWUoeoIWmMkAHfiF11vA9d6rhiSjPDL0WFGiSr/Et+wwG7gOrLf8yovmtgSJlooqa7lcMtipTxegPAYtd5yZg==")
        else
        {
            print("Unable to get base64 encoded key from the provided string.")
            XCTFail()
            return
        }
        
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

        guard let removeSequence = SequenceModel(sequence: "Hello, hello!".data, length: 120)
            else
        {
            print("\nUnable to generate an add sequence.\n")
            XCTFail()
            return
        }
        
        guard let addSequence = SequenceModel(sequence: "Goodbye!".data, length: 200)
            else
        {
            print("\nUnable to generate a remove sequence.\n")
            XCTFail()
            return
        }
  
//        guard let whalesong = WhalesongClient(addSequences: [addSequence], removeSequences: [removeSequence]) else
//        {
//            print("Failed to initialize ToneBurst.")
//            XCTFail()
//            return
//        }

        //let toneburst = ToneBurstClientConfig.whalesong(client: whalesong)
        
        // Make a Client Connection
        guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKey, chunkSize: chunkSize, chunkTimeout: chunkTimeout, toneBurst: nil)
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
    
    
    func testExample() throws
    {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        // Some of the APIs that we use below are available in macOS 10.13 and above.
        guard #available(macOS 10.13, *) else {
            return
        }

        let fooBinary = productsDirectory.appendingPathComponent("ReplicantSwiftServer")

        let process = Process()
        process.executableURL = fooBinary

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        //XCTAssertEqual(output, "Hello, world!\n")
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

    static var allTests = [
        ("testExample", testExample),
    ]
}
