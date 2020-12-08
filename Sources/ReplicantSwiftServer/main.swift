import Network
import Transport
import Foundation
import ReplicantSwiftServerCore

print("\nI'm here to listen for Replicants.")

let replicantServer = ReplicantServer()
let consoleIO = ConsoleIO()

var appLog = Logger(label: "org.OperatorFoundation.ReplicantSwiftServer.Linux")

replicantServer.processRequest()


