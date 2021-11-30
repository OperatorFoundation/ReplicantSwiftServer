import Foundation
import Logging
import ReplicantSwiftServerCore
import Net

print("\nI'm here to listen for Replicants.")


let consoleIO = ConsoleIO()

var appLog = Logger(label: "org.OperatorFoundation.ReplicantSwiftServer.Linux")

if let replicantServer = ReplicantServer()
{
    replicantServer.processRequest()
}
else
{
    print("Unable to process your request: Failed to launch the Replicant Server.")
}



