import Transport
import Foundation
import ReplicantSwiftServerCore

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

print("\nI'm here to listen for Replicants.")


let consoleIO = ConsoleIO()

var appLog = Logger(label: "org.OperatorFoundation.ReplicantSwiftServer.Linux")

if let replicantServer = ReplicantServer(logger: appLog)
{
    replicantServer.processRequest()
}
else
{
    print("Unable to process your request: Failed to launch the Replicant Server.")
}



