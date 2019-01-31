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
        
        let configTemplate = ReplicantConfigTemplate(chunkSize: chunkSize, chunkTimeout: chunkTimeout, addSequences: nil, removeSequences: nil)
        guard let directory = getApplicationDirectory()
        else
        {
            return
        }
        guard let jsonData = configTemplate?.createJSON()
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
        
        // Create a test ReplicantServerConfig
        guard let replicantConfig = ReplicantServerConfig(serverPublicKey: publicKey, chunkSize: 800, chunkTimeout: 120, addSequences: [addSequence], removeSequences: [removeSequence])
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
        let host = NWEndpoint.Host("127.0.0.1")
        guard let port = NWEndpoint.Port(rawValue: 51820)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        guard let appDirectoryURL = getApplicationDirectory()
        else
        {
            XCTFail()
            return
        }
        
        // Get config files created by above tests
        let routingController = RoutingController()
        let serverConfigFileName = "Server.config"
        let serverConfigPath = appDirectoryURL.appendingPathComponent(serverConfigFileName).path
        guard let serverConfig = ServerConfig.parseJSON(atPath: serverConfigPath)
        else
        {
            XCTFail()
            return
        }

        let replicantConfigFileName = "ReplicantServer.config"
        let replicantConfigPath = appDirectoryURL.appendingPathComponent(replicantConfigFileName).path
        guard let replicantServerConfig = ReplicantServerConfig.parseJSON(atPath: replicantConfigPath)
        else
        {
            XCTFail()
            return
        }

        // Launch a server
        routingController.startListening(serverConfig: serverConfig, replicantConfig: replicantServerConfig, replicantEnabled: true)
        
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
        
        ///FIXME: This doesn't work if there is a server private key in the keychain
        guard let polishServer = PolishServerModel()
            else
        {
            print("\nUnable to generate a key for the server\n")
            XCTFail()
            return
        }
        
        let serverPublicKey = polishServer.publicKey
        
        // Encode key as data
        var error: Unmanaged<CFError>?
        
        guard let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, &error) as Data?
            else
        {
            print("\nUnable to generate public key external representation: \(error!.takeRetainedValue() as Error)\n")
            XCTFail()
            return
        }
        
        // Make a Client Connection
        guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKeyData, chunkSize: 800, chunkTimeout: 120, addSequences: [addSequence], removeSequences: [removeSequence])
            else
        {
            print("\nUnable to create ReplicantClient config.\n")
            XCTFail()
            return
        }
        
        let clientConnectionFactory = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig)
        guard let clientConnection = clientConnectionFactory.connect(using: .tcp)
        else
        {
            XCTFail()
            return
        }
        
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
