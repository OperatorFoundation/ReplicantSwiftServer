import Network
import Transport
import Foundation

print("\nI'm here to listen for Replicants.")

let replicantServer = ReplicantServer()
let consoleIO = ConsoleIO()

if CommandLine.argc < 2
{
    //Handle invalid command
    consoleIO.printUsage()
}
else
{
    replicantServer.processRequest()
}


