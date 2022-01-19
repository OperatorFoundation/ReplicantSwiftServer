import ArgumentParser
import Foundation
import Logging

import ReplicantSwiftServerCore
import Net

var appLog = Logger(label: "org.OperatorFoundation.ReplicantSwiftServer.Linux")

enum Command {}

extension Command
{
    struct Main: ParsableCommand
    {
        static var configuration: CommandConfiguration
        {
            .init(
                commandName: "ReplicantServer",
                abstract: "A program that can run a ReplicantTransportServer and create a config file compatible with that server.",
                subcommands: [
                    Command.Launch.self,
                    Command.WriteConfig.self
                ]
            )
        }
    }
}

Command.Main.main()

signal(SIGINT)
{
    (theSignal) in

    print("Force exited ReplicantServer!! 😮")

    exit(0)
}



