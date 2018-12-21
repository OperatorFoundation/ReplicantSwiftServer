import XCTest
import ReplicantSwift
import Replicant
import Network

import class Foundation.Bundle

final class ReplicantSwiftServerTests: XCTestCase {
    
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
        
        guard let replicantConfig = ReplicantServerConfig(serverPublicKey: publicKey, chunkSize: 800, chunkTimeout: 120, addSequences: [addSequence], removeSequences: [removeSequence])
        else
        {
            print("\nUnable to create ReplicantServer config.\n")
            XCTFail()
            return
        }
        
        guard let jsonData = replicantConfig.createJSON()
            else
        {
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
        
        let serverConfig = ServerConfig(withPort: port)
        
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
